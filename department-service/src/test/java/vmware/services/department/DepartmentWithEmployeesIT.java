package vmware.services.department;

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
import vmware.services.department.client.EmployeeClient;
import vmware.services.department.model.Department;
import vmware.services.department.repository.DepartmentRepository;

/**
 * Cross-service fan-out integration test. Stubs the employee-service peer with WireMock and
 * verifies that {@code /organization/{id}/with-employees} hydrates each department's employees via
 * a real HTTP call through the @HttpExchange client.
 */
@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "spring.main.allow-bean-definition-overriding=true")
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
@Import(DepartmentWithEmployeesIT.WireMockClientConfig.class)
class DepartmentWithEmployeesIT {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.0.20");

  static WireMockServer wireMock;

  @Autowired RestTestClient client;

  @Autowired DepartmentRepository repository;

  @BeforeAll
  static void startWireMock() {
    wireMock = new WireMockServer(WireMockConfiguration.options().dynamicPort());
    wireMock.start();
  }

  @AfterAll
  static void stopWireMock() {
    if (wireMock != null) {
      wireMock.stop();
    }
  }

  @DynamicPropertySource
  static void registerWireMockUrl(DynamicPropertyRegistry registry) {
    registry.add("wiremock.employee.base-url", () -> wireMock.baseUrl());
  }

  @BeforeEach
  void resetState() {
    repository.deleteAll();
    wireMock.resetAll();
  }

  @Test
  void shouldFanOutToEmployeeServiceAndReturnHydratedDepartments() {
    Department engineering = repository.save(new Department(42L, "Engineering"));
    String deptId = engineering.getId();

    wireMock.stubFor(
        get(urlPathMatching("/department/" + deptId))
            .willReturn(
                aResponse()
                    .withHeader("Content-Type", "application/json")
                    .withBody(
                        "[{\"id\":1,\"name\":\"Alice\",\"age\":30,\"position\":\"engineer\"},"
                            + "{\"id\":2,\"name\":\"Bob\",\"age\":35,\"position\":\"architect\"}]")));

    client
        .get()
        .uri("/organization/42/with-employees")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Department[].class)
        .value(
            body -> {
              assertThat(body).hasSize(1);
              assertThat(body[0].getName()).isEqualTo("Engineering");
              assertThat(body[0].getEmployees()).hasSize(2);
              assertThat(body[0].getEmployees())
                  .extracting("name")
                  .containsExactlyInAnyOrder("Alice", "Bob");
            });

    // Verify the HTTP call shape: correct method, path template, and Accept header.
    wireMock.verify(
        getRequestedFor(urlPathMatching("/department/" + deptId))
            .withHeader("Accept", equalTo("application/json")));
  }

  /**
   * Test-scoped override for {@link EmployeeClient}. The main configuration builds the client
   * against {@code http://employee} (resolved via Spring Cloud LoadBalancer). For integration
   * testing we point it at the WireMock baseUrl injected via {@code @DynamicPropertySource}.
   */
  @TestConfiguration
  static class WireMockClientConfig {

    @Bean
    @Primary
    EmployeeClient employeeClient(
        @org.springframework.beans.factory.annotation.Value("${wiremock.employee.base-url}")
            String baseUrl) {
      RestClient restClient = RestClient.builder().baseUrl(baseUrl).build();
      return HttpServiceProxyFactory.builderFor(RestClientAdapter.create(restClient))
          .build()
          .createClient(EmployeeClient.class);
    }
  }
}
