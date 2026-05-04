#!/bin/bash
set -uo pipefail

# ---------------------------------------------------------------------------
# E2E test suite for Spring Boot microservices deployed on Kind + cloud-provider-kind
# Tests employee, department, organization services via the Spring Cloud Gateway.
# ---------------------------------------------------------------------------

# Pin every kubectl call to OUR cluster's context so a parallel `make` from
# another KinD-using project (kubectl config use-context) cannot steal our
# default context mid-run. Cluster name is passed by the Makefile e2e-test
# recipe; falls back to the project default when invoked directly for ad-hoc
# use against an already-running cluster.
KUBECTL=(kubectl --context="kind-${KIND_CLUSTER_NAME:-spring-microservices-k8s}")

# --- Gateway discovery ------------------------------------------------------

GATEWAY_IP=$("${KUBECTL[@]}" get svc gateway -n gateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

if [[ -z "${GATEWAY_IP}" ]]; then
  echo "ERROR: Could not obtain gateway LoadBalancer IP. Is the gateway service deployed?"
  exit 1
fi

BASE_URL="http://${GATEWAY_IP}:8080"
echo "Gateway URL: ${BASE_URL}"

# --- Counters ---------------------------------------------------------------

PASS=0
FAIL=0

# --- Helpers ----------------------------------------------------------------

check_response() {
  local test_name="$1"
  local actual="$2"
  local expected="$3"

  if echo "${actual}" | grep -qF "${expected}"; then
    echo "  PASS: ${test_name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${test_name}"
    echo "        expected substring: ${expected}"
    echo "        actual response:    ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

# Assert HTTP status code for a request.
check_status() {
  local test_name="$1"
  local method="$2"
  local url="$3"
  local expected="$4"
  local body="${5:-}"
  local opts=(-s -o /dev/null -w '%{http_code}' -X "${method}" --max-time 30)
  if [[ -n "${body}" ]]; then
    opts+=(-H 'Content-Type: application/json' -d "${body}")
  fi
  local actual
  actual=$(curl "${opts[@]}" "${url}" 2>/dev/null || true)
  if [[ "${actual}" == "${expected}" ]]; then
    echo "  PASS: ${test_name} (HTTP ${actual})"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${test_name}"
    echo "        expected HTTP:      ${expected}"
    echo "        actual HTTP:        ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

# Assert a jq expression against a JSON payload. Requires `jq` on PATH.
check_jq() {
  local test_name="$1"
  local payload="$2"
  local jq_expr="$3"
  local expected="$4"
  if ! command -v jq >/dev/null 2>&1; then
    echo "  SKIP: ${test_name} (jq not installed)"
    return
  fi
  local actual
  actual=$(echo "${payload}" | jq -r "${jq_expr}" 2>/dev/null || true)
  if [[ "${actual}" == "${expected}" ]]; then
    echo "  PASS: ${test_name} (${jq_expr} == ${expected})"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${test_name}"
    echo "        jq expression:      ${jq_expr}"
    echo "        expected:           ${expected}"
    echo "        actual:             ${actual}"
    echo "        payload:            ${payload}"
    FAIL=$((FAIL + 1))
  fi
}

# --- Wait for gateway readiness --------------------------------------------

echo ""
echo "Waiting for gateway to become ready ..."
READY=0
for i in $(seq 1 30); do
  HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/actuator/health" 2>/dev/null || true)
  if [[ "${HEALTH}" == "200" ]]; then
    READY=1
    echo "Gateway is ready (attempt ${i}/30)."
    break
  fi
  echo "  Attempt ${i}/30 — gateway not ready yet (HTTP ${HEALTH}). Retrying in 10s ..."
  sleep 10
done

if [[ "${READY}" -ne 1 ]]; then
  echo "ERROR: Gateway did not become ready within 300 seconds."
  exit 1
fi

# ===========================================================================
# Tests
# ===========================================================================

# --- Wait for gateway to discover backend services -----------------------------

echo "Waiting for gateway to discover backend services ..."
for i in $(seq 1 30); do
  RESP=$(curl -s --max-time 30 "${BASE_URL}/employee/" 2>/dev/null || true)
  if echo "${RESP}" | grep -qF "["; then
    echo "Gateway routing is active (attempt ${i}/30)."
    break
  fi
  echo "  Attempt ${i}/30 — backend services not yet routable. Retrying in 10s ..."
  sleep 10
done

echo ""
echo "=== Running E2E tests ==="
echo ""

# Test 1: Gateway health -----------------------------------------------------
echo "[Test 1] Gateway health"
RESP=$(curl -s --max-time 30 "${BASE_URL}/actuator/health" 2>/dev/null || true)
check_response "GET /actuator/health returns UP" "${RESP}" "UP"

# Test 2: Create employee Smith ----------------------------------------------
echo "[Test 2] Create employee Smith"
RESP=$(curl -s --max-time 30 -X POST "${BASE_URL}/employee/" \
  -H "Content-Type: application/json" \
  -d '{"age":25,"departmentId":1,"id":"1","name":"Smith","organizationId":1,"position":"engineer"}' 2>/dev/null || true)
check_response "POST /employee/ — Smith created" "${RESP}" "Smith"

# Test 3: Create employee Johns ----------------------------------------------
echo "[Test 3] Create employee Johns"
RESP=$(curl -s --max-time 30 -X POST "${BASE_URL}/employee/" \
  -H "Content-Type: application/json" \
  -d '{"age":45,"departmentId":1,"id":"2","name":"Johns","organizationId":1,"position":"manager"}' 2>/dev/null || true)
check_response "POST /employee/ — Johns created" "${RESP}" "Johns"

# Test 4: List employees ------------------------------------------------------
echo "[Test 4] List employees"
RESP=$(curl -s --max-time 30 "${BASE_URL}/employee/") || true
check_response "GET /employee/ — contains Smith" "${RESP}" "Smith"
check_response "GET /employee/ — contains Johns" "${RESP}" "Johns"

# Test 5: Create department ---------------------------------------------------
echo "[Test 5] Create department"
RESP=$(curl -s --max-time 30 -X POST "${BASE_URL}/department/" \
  -H "Content-Type: application/json" \
  -d '{"id":"1","name":"RD Dept.","organizationId":1}' 2>/dev/null || true)
check_response "POST /department/ — RD Dept. created" "${RESP}" "RD Dept."

# Test 6: List departments ----------------------------------------------------
echo "[Test 6] List departments"
RESP=$(curl -s --max-time 30 "${BASE_URL}/department/") || true
check_response "GET /department/ — contains RD Dept." "${RESP}" "RD Dept."

# Test 7: Create organization -------------------------------------------------
echo "[Test 7] Create organization"
RESP=$(curl -s --max-time 30 -X POST "${BASE_URL}/organization/" \
  -H "Content-Type: application/json" \
  -d '{"id":"1","name":"MegaCorp","address":"Main Street"}' 2>/dev/null || true)
check_response "POST /organization/ — MegaCorp created" "${RESP}" "MegaCorp"

# Test 8: Get organization with employees (cross-service) ---------------------
echo "[Test 8] Get organization with employees (cross-service)"
RESP=$(curl -s --max-time 30 "${BASE_URL}/organization/1/with-employees") || true
check_response "GET /organization/1/with-employees — contains MegaCorp" "${RESP}" "MegaCorp"

# Test 9: Get organization with departments (cross-service) -------------------
echo "[Test 9] Get organization with departments (cross-service)"
RESP=$(curl -s --max-time 30 "${BASE_URL}/organization/1/with-departments") || true
check_response "GET /organization/1/with-departments — contains MegaCorp" "${RESP}" "MegaCorp"

# Test 10: Deep fan-out (org -> dept -> employees) ----------------------------
# Exercises the three-service chain through the gateway:
# organization-service -> department-service -> employee-service.
echo "[Test 10] Get organization with departments and employees (deep fan-out)"
RESP=$(curl -s --max-time 30 "${BASE_URL}/organization/1/with-departments-and-employees") || true
check_response "GET /organization/1/with-departments-and-employees — contains MegaCorp" \
  "${RESP}" "MegaCorp"
check_response "GET /organization/1/with-departments-and-employees — contains RD Dept." \
  "${RESP}" "RD Dept."
# Assert the nested response shape: organization has at least one department, and
# that department exposes an employees[] array (hydrated by the deep fan-out).
check_jq "deep fan-out response has organization name" "${RESP}" '.name' "MegaCorp"
check_jq "deep fan-out response has at least one department" "${RESP}" \
  '.departments | length > 0' "true"
check_jq "deep fan-out response first department has employees[] array" "${RESP}" \
  '.departments[0].employees | type' "array"

# Test 11: Negative — GET unknown employee id ---------------------------------
# EmployeeController.findById throws ResponseStatusException(NOT_FOUND) when the
# id is missing — surfaces through the gateway as a 404.
echo "[Test 11] Negative: GET /employee/nonexistent — expect 404"
check_status "GET /employee/nonexistent-id returns 404" \
  GET "${BASE_URL}/employee/nonexistent-id" 404

# Test 12: Negative — POST employee with malformed JSON body ------------------
# Jackson rejects invalid JSON with 400 Bad Request before the controller runs.
echo "[Test 12] Negative: POST /employee/ with invalid body"
check_status "POST /employee/ with invalid JSON returns 400" \
  POST "${BASE_URL}/employee/" 400 '{not valid json'

# Test 13: List employees by departmentId (gateway-routed) --------------------
# Exercises the foreign-key finder through the gateway; both seeded employees
# share departmentId=1, so the response must contain both names.
echo "[Test 13] GET /employee/department/1 — list by departmentId"
RESP=$(curl -s --max-time 30 "${BASE_URL}/employee/department/1") || true
check_response "GET /employee/department/1 — contains Smith" "${RESP}" "Smith"
check_response "GET /employee/department/1 — contains Johns" "${RESP}" "Johns"

# Test 14: List employees by organizationId (gateway-routed) ------------------
# Both seeded employees share organizationId=1, so the response must contain both.
echo "[Test 14] GET /employee/organization/1 — list by organizationId"
RESP=$(curl -s --max-time 30 "${BASE_URL}/employee/organization/1") || true
check_response "GET /employee/organization/1 — contains Smith" "${RESP}" "Smith"
check_response "GET /employee/organization/1 — contains Johns" "${RESP}" "Johns"

# Test 15: Jaeger UI reachable (observability stack) --------------------------
# Jaeger runs in the `observability` namespace and exposes the query UI on
# port 16686 via a LoadBalancer Service. Allocated by cloud-provider-kind on
# the `kind` Docker network; same as the gateway. A reachable UI is the
# operator-visible signal that OTLP traces from the four services have
# somewhere to land.
echo "[Test 15] Jaeger UI reachable"
JAEGER_IP=$("${KUBECTL[@]}" get svc jaeger -n observability \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
if [[ -z "${JAEGER_IP}" ]]; then
  echo "  FAIL: Jaeger LoadBalancer IP not allocated (cloud-provider-kind not running?)"
  FAIL=$((FAIL + 1))
else
  check_status "GET http://${JAEGER_IP}:16686/ returns 200" \
    GET "http://${JAEGER_IP}:16686/" 200
fi

# Test 16: OTLP pipeline (services registered) and traceparent propagation
# Two-stage diagnostic:
#   16a — proves OTLP egress works at all by asking Jaeger which services
#         have ever sent it spans. If 16a fails, the pipeline is broken
#         (Spring tracing config, OTLP endpoint reachability, or Jaeger
#         ingest) — debug there before looking at traceparent.
#   16b — sends one deep fan-out with an injected W3C traceparent header
#         and asserts the same trace id round-trips through all four
#         services into Jaeger. Proves Micrometer Tracing honors inbound
#         trace context AND propagates it on outbound RestClient calls.
# Pre-reqs: openssl + jq.
echo "[Test 16] OTLP pipeline and traceparent propagation"
if [[ -z "${JAEGER_IP}" ]]; then
  echo "  SKIP: Jaeger LoadBalancer IP unavailable"
elif ! command -v jq >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1; then
  echo "  SKIP: jq + openssl required for trace assertions"
else
  # The deep fan-out request from Test 10 already exercised the chain; that
  # means traces should be reaching Jaeger by now. Poll the services list
  # until all four are registered (or 30 s elapse).
  SVC_LIST=""
  for i in $(seq 1 15); do
    SVC_LIST=$(curl -s --max-time 10 "http://${JAEGER_IP}:16686/api/services" 2>/dev/null \
      | jq -r '.data[]?' 2>/dev/null | sort -u | tr '\n' ',' || true)
    if echo "${SVC_LIST}" | grep -q "gateway," \
      && echo "${SVC_LIST}" | grep -q "organization," \
      && echo "${SVC_LIST}" | grep -q "department," \
      && echo "${SVC_LIST}" | grep -q "employee,"; then
      break
    fi
    sleep 2
  done
  echo "  [16a] Jaeger /api/services → ${SVC_LIST:-<none>}"
  check_response "Jaeger has registered service: gateway"      "${SVC_LIST}" "gateway,"
  check_response "Jaeger has registered service: organization" "${SVC_LIST}" "organization,"
  check_response "Jaeger has registered service: department"   "${SVC_LIST}" "department,"
  check_response "Jaeger has registered service: employee"     "${SVC_LIST}" "employee,"

  # 16b — inject traceparent and verify Jaeger sees the same id from all 4 services
  TRACE_ID=$(openssl rand -hex 16)
  SPAN_ID=$(openssl rand -hex 8)
  curl -s -o /dev/null --max-time 30 \
    -H "traceparent: 00-${TRACE_ID}-${SPAN_ID}-01" \
    "${BASE_URL}/organization/1/with-departments-and-employees" || true

  TRACE_RESP=""
  TRACE_SERVICES=""
  for i in $(seq 1 15); do
    TRACE_RESP=$(curl -s --max-time 10 "http://${JAEGER_IP}:16686/api/traces/${TRACE_ID}" 2>/dev/null || true)
    TRACE_SERVICES=$(echo "${TRACE_RESP}" \
      | jq -r '[.data[]?.processes[]?.serviceName] | unique | sort | join(",")' 2>/dev/null || true)
    if echo "${TRACE_SERVICES}" | grep -q "gateway" \
      && echo "${TRACE_SERVICES}" | grep -q "organization" \
      && echo "${TRACE_SERVICES}" | grep -q "department" \
      && echo "${TRACE_SERVICES}" | grep -q "employee"; then
      break
    fi
    sleep 2
  done
  echo "  [16b] Trace ${TRACE_ID} → services: ${TRACE_SERVICES:-<none>}"
  # On failure, dump the raw Jaeger response (truncated) so the diagnostic
  # points straight at the broken hop instead of a generic empty list.
  if [[ -z "${TRACE_SERVICES}" ]]; then
    echo "       Jaeger raw response (first 400 chars): ${TRACE_RESP:0:400}"
  fi
  check_response "trace ${TRACE_ID} contains gateway"      "${TRACE_SERVICES}" "gateway"
  check_response "trace ${TRACE_ID} contains organization" "${TRACE_SERVICES}" "organization"
  check_response "trace ${TRACE_ID} contains department"   "${TRACE_SERVICES}" "department"
  check_response "trace ${TRACE_ID} contains employee"     "${TRACE_SERVICES}" "employee"
fi

# ===========================================================================
# Summary
# ===========================================================================

TOTAL=$((PASS + FAIL))
echo ""
echo "==========================================="
echo "  E2E Test Summary"
echo "==========================================="
echo "  Total:  ${TOTAL}"
echo "  Passed: ${PASS}"
echo "  Failed: ${FAIL}"
echo "==========================================="

if [[ "${FAIL}" -gt 0 ]]; then
  echo "Some tests FAILED."
  exit 1
fi

echo "All tests PASSED."
exit 0
