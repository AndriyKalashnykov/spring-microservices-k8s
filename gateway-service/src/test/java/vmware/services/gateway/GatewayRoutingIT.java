package vmware.services.gateway;

import static com.github.tomakehurst.wiremock.client.WireMock.aResponse;
import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.getRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.urlPathMatching;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.cloud.gateway.server.mvc.filter.BeforeFilterFunctions.stripPrefix;
import static org.springframework.cloud.gateway.server.mvc.handler.GatewayRouterFunctions.route;
import static org.springframework.cloud.gateway.server.mvc.predicate.GatewayRequestPredicates.path;

import com.github.tomakehurst.wiremock.WireMockServer;
import com.github.tomakehurst.wiremock.core.WireMockConfiguration;
import java.net.URI;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringBootConfiguration;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.cloud.gateway.server.mvc.handler.HandlerFunctions;
import org.springframework.context.annotation.Bean;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.client.RestTestClient;
import org.springframework.web.servlet.function.RouterFunction;
import org.springframework.web.servlet.function.ServerResponse;

/**
 * Gateway routing integration test. The production {@link GatewayApplication} wires routes with
 * {@code lb("service-name")} — the Spring Cloud LoadBalancer filter — which requires a live
 * Kubernetes DiscoveryClient to resolve targets. Stubbing that out is not reasonable, so this test
 * boots a minimal {@link SpringBootConfiguration} that mirrors the production routing topology but
 * replaces each {@code lb(...)} hop with a static URI pointing at the corresponding WireMock
 * upstream. The path predicates, the {@code stripPrefix(1)} filter and the {@code
 * HandlerFunctions.http()} handler are identical to production, so this verifies the routing shape
 * end-to-end.
 */
@SpringBootTest(
    classes = GatewayRoutingIT.TestRoutingConfig.class,
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
class GatewayRoutingIT {

  static WireMockServer employeeStub;

  static WireMockServer departmentStub;

  static WireMockServer organizationStub;

  @Autowired RestTestClient client;

  @BeforeAll
  static void startWireMock() {
    employeeStub = new WireMockServer(WireMockConfiguration.options().dynamicPort());
    departmentStub = new WireMockServer(WireMockConfiguration.options().dynamicPort());
    organizationStub = new WireMockServer(WireMockConfiguration.options().dynamicPort());
    employeeStub.start();
    departmentStub.start();
    organizationStub.start();
  }

  @AfterAll
  static void stopWireMock() {
    if (employeeStub != null) {
      employeeStub.stop();
    }
    if (departmentStub != null) {
      departmentStub.stop();
    }
    if (organizationStub != null) {
      organizationStub.stop();
    }
  }

  @DynamicPropertySource
  static void registerWireMockUrls(DynamicPropertyRegistry registry) {
    registry.add("gateway.test.employee-url", () -> employeeStub.baseUrl());
    registry.add("gateway.test.department-url", () -> departmentStub.baseUrl());
    registry.add("gateway.test.organization-url", () -> organizationStub.baseUrl());
  }

  @BeforeEach
  void resetStubs() {
    employeeStub.resetAll();
    departmentStub.resetAll();
    organizationStub.resetAll();
  }

  @Test
  void employeePrefixRoutesToEmployeeUpstream() {
    employeeStub.stubFor(
        get(urlPathMatching("/"))
            .willReturn(
                aResponse()
                    .withHeader("Content-Type", "application/json")
                    .withBody("[{\"id\":1,\"name\":\"Alice\"}]")));

    client
        .get()
        .uri("/employee/")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(String.class)
        .value(body -> assertThat(body).contains("Alice"));

    employeeStub.verify(getRequestedFor(urlPathMatching("/")));
    assertThat(departmentStub.getAllServeEvents()).isEmpty();
    assertThat(organizationStub.getAllServeEvents()).isEmpty();
  }

  @Test
  void departmentPrefixRoutesToDepartmentUpstream() {
    departmentStub.stubFor(
        get(urlPathMatching("/organization/42"))
            .willReturn(
                aResponse()
                    .withHeader("Content-Type", "application/json")
                    .withBody("[{\"id\":1,\"name\":\"Engineering\"}]")));

    client
        .get()
        .uri("/department/organization/42")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(String.class)
        .value(body -> assertThat(body).contains("Engineering"));

    departmentStub.verify(getRequestedFor(urlPathMatching("/organization/42")));
  }

  @Test
  void organizationPrefixRoutesToOrganizationUpstream() {
    organizationStub.stubFor(
        get(urlPathMatching("/"))
            .willReturn(
                aResponse()
                    .withHeader("Content-Type", "application/json")
                    .withBody("[{\"id\":1,\"name\":\"MegaCorp\"}]")));

    client
        .get()
        .uri("/organization/")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(String.class)
        .value(body -> assertThat(body).contains("MegaCorp"));

    organizationStub.verify(getRequestedFor(urlPathMatching("/")));
  }

  @Test
  void unknownPrefixReturnsNotFound() {
    client.get().uri("/unknown/path").exchange().expectStatus().isNotFound();

    assertThat(employeeStub.getAllServeEvents()).isEmpty();
    assertThat(departmentStub.getAllServeEvents()).isEmpty();
    assertThat(organizationStub.getAllServeEvents()).isEmpty();
  }

  /**
   * Minimal Spring Boot configuration that mirrors {@link GatewayApplication}'s routing topology
   * but substitutes static URIs (WireMock upstreams) for the production {@code lb(...)} filter.
   * This avoids booting Spring Cloud Kubernetes discovery in the test.
   */
  @SpringBootConfiguration
  @EnableAutoConfiguration
  static class TestRoutingConfig {

    @Bean
    RouterFunction<ServerResponse> testEmployeeRoute(
        @Value("${gateway.test.employee-url}") String employeeUrl) {
      return route("employee")
          .route(path("/employee", "/employee/**"), HandlerFunctions.http(URI.create(employeeUrl)))
          .before(stripPrefix(1))
          .build();
    }

    @Bean
    RouterFunction<ServerResponse> testDepartmentRoute(
        @Value("${gateway.test.department-url}") String departmentUrl) {
      return route("department")
          .route(
              path("/department", "/department/**"),
              HandlerFunctions.http(URI.create(departmentUrl)))
          .before(stripPrefix(1))
          .build();
    }

    @Bean
    RouterFunction<ServerResponse> testOrganizationRoute(
        @Value("${gateway.test.organization-url}") String organizationUrl) {
      return route("organization")
          .route(
              path("/organization", "/organization/**"),
              HandlerFunctions.http(URI.create(organizationUrl)))
          .before(stripPrefix(1))
          .build();
    }
  }
}
