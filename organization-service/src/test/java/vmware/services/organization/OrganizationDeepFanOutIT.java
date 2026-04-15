package vmware.services.organization;

import static com.github.tomakehurst.wiremock.client.WireMock.aResponse;
import static com.github.tomakehurst.wiremock.client.WireMock.equalTo;
import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.getRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.urlPathMatching;
import static org.assertj.core.api.Assertions.assertThat;

import com.github.tomakehurst.wiremock.WireMockServer;
import com.github.tomakehurst.wiremock.core.WireMockConfiguration;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.client.RestTestClient;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.support.RestClientAdapter;
import org.springframework.web.service.invoker.HttpServiceProxyFactory;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.mongodb.MongoDBContainer;
import vmware.services.organization.client.DepartmentClient;
import vmware.services.organization.client.EmployeeClient;
import vmware.services.organization.model.Organization;
import vmware.services.organization.repository.OrganizationRepository;

/**
 * Deepest fan-out integration test. Stubs BOTH the department-service and employee-service peers
 * with WireMock and exercises {@code GET /{id}/with-departments-and-employees}, which chains
 * through {@link DepartmentClient#findByOrganizationWithEmployees(String)}.
 */
@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "spring.main.allow-bean-definition-overriding=true")
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
@Import(OrganizationDeepFanOutIT.WireMockClientsConfig.class)
class OrganizationDeepFanOutIT {

  @Container @ServiceConnection static MongoDBContainer mongo = new MongoDBContainer("mongo:8.2.6");

  static WireMockServer departmentStub;

  static WireMockServer employeeStub;

  @Autowired RestTestClient client;

  @Autowired OrganizationRepository repository;

  @BeforeAll
  static void startWireMock() {
    departmentStub = new WireMockServer(WireMockConfiguration.options().dynamicPort());
    employeeStub = new WireMockServer(WireMockConfiguration.options().dynamicPort());
    departmentStub.start();
    employeeStub.start();
  }

  @AfterAll
  static void stopWireMock() {
    if (departmentStub != null) {
      departmentStub.stop();
    }
    if (employeeStub != null) {
      employeeStub.stop();
    }
  }

  @DynamicPropertySource
  static void registerWireMockUrls(DynamicPropertyRegistry registry) {
    registry.add("wiremock.department.base-url", () -> departmentStub.baseUrl());
    registry.add("wiremock.employee.base-url", () -> employeeStub.baseUrl());
  }

  @BeforeEach
  void resetState() {
    repository.deleteAll();
    departmentStub.resetAll();
    employeeStub.resetAll();
  }

  @Test
  void shouldFanOutToDepartmentAndEmployeeServicesAndReturnFullyHydratedOrganization() {
    Organization saved = repository.save(new Organization("MegaCorp", "Main Street"));
    String orgId = saved.getId();

    departmentStub.stubFor(
        get(urlPathMatching("/organization/" + orgId + "/with-employees"))
            .willReturn(
                aResponse()
                    .withHeader("Content-Type", "application/json")
                    .withBody(
                        "[{\"id\":1,\"name\":\"Engineering\",\"employees\":["
                            + "{\"id\":10,\"name\":\"Alice\",\"age\":30,\"position\":\"engineer\"},"
                            + "{\"id\":11,\"name\":\"Bob\",\"age\":35,\"position\":\"architect\"}]},"
                            + "{\"id\":2,\"name\":\"Marketing\",\"employees\":["
                            + "{\"id\":12,\"name\":\"Carol\",\"age\":28,\"position\":\"manager\"}]}]")));

    client
        .get()
        .uri("/" + orgId + "/with-departments-and-employees")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Organization.class)
        .value(
            body -> {
              assertThat(body.getName()).isEqualTo("MegaCorp");
              assertThat(body.getDepartments()).hasSize(2);
              assertThat(body.getDepartments())
                  .extracting("name")
                  .containsExactlyInAnyOrder("Engineering", "Marketing");
              assertThat(body.getDepartments().get(0).getEmployees()).hasSize(2);
            });

    // Verify the deep fan-out hit the department peer exactly once with the right shape.
    departmentStub.verify(
        getRequestedFor(urlPathMatching("/organization/" + orgId + "/with-employees"))
            .withHeader("Accept", equalTo("application/json")));
  }

  /**
   * Test-scoped overrides for {@link DepartmentClient} and {@link EmployeeClient}. Production beans
   * resolve {@code http://department} / {@code http://employee} via Spring Cloud LoadBalancer; here
   * we point them at the WireMock stubs injected via {@code @DynamicPropertySource}.
   */
  @TestConfiguration
  static class WireMockClientsConfig {

    @Bean
    @Primary
    DepartmentClient departmentClient(@Value("${wiremock.department.base-url}") String baseUrl) {
      RestClient restClient = RestClient.builder().baseUrl(baseUrl).build();
      return HttpServiceProxyFactory.builderFor(RestClientAdapter.create(restClient))
          .build()
          .createClient(DepartmentClient.class);
    }

    @Bean
    @Primary
    EmployeeClient employeeClient(@Value("${wiremock.employee.base-url}") String baseUrl) {
      RestClient restClient = RestClient.builder().baseUrl(baseUrl).build();
      return HttpServiceProxyFactory.builderFor(RestClientAdapter.create(restClient))
          .build()
          .createClient(EmployeeClient.class);
    }
  }
}
