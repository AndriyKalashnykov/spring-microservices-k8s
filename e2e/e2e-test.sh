#!/bin/bash
set -uo pipefail

# ---------------------------------------------------------------------------
# E2E test suite for Spring Boot microservices deployed on Kind + MetalLB
# Tests employee, department, organization services via the Spring Cloud Gateway.
# ---------------------------------------------------------------------------

# --- Gateway discovery ------------------------------------------------------

GATEWAY_IP=$(kubectl get svc gateway -n gateway \
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
