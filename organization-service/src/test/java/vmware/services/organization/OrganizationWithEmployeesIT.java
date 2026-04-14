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
import vmware.services.organization.client.EmployeeClient;
import vmware.services.organization.model.Organization;
import vmware.services.organization.repository.OrganizationRepository;

/**
 * Single-level fan-out integration test for {@code GET /{id}/with-employees}. Stubs the
 * employee-service peer with WireMock and verifies the organization payload gains a hydrated {@code
 * employees[]} array.
 */
@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "spring.main.allow-bean-definition-overriding=true")
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
@Import(OrganizationWithEmployeesIT.WireMockClientConfig.class)
class OrganizationWithEmployeesIT {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.0.20");

  static WireMockServer employeeStub;

  @Autowired RestTestClient client;

  @Autowired OrganizationRepository repository;

  @BeforeAll
  static void startWireMock() {
    employeeStub = new WireMockServer(WireMockConfiguration.options().dynamicPort());
    employeeStub.start();
  }

  @AfterAll
  static void stopWireMock() {
    if (employeeStub != null) {
      employeeStub.stop();
    }
  }

  @DynamicPropertySource
  static void registerWireMockUrl(DynamicPropertyRegistry registry) {
    registry.add("wiremock.employee.base-url", () -> employeeStub.baseUrl());
  }

  @BeforeEach
  void resetState() {
    repository.deleteAll();
    employeeStub.resetAll();
  }

  @Test
  void shouldFanOutToEmployeeServiceAndReturnHydratedOrganization() {
    Organization saved = repository.save(new Organization("MegaCorp", "Main Street"));
    String orgId = saved.getId();

    employeeStub.stubFor(
        get(urlPathMatching("/organization/" + orgId))
            .willReturn(
                aResponse()
                    .withHeader("Content-Type", "application/json")
                    .withBody(
                        "[{\"id\":1,\"name\":\"Alice\",\"age\":30,\"position\":\"engineer\"},"
                            + "{\"id\":2,\"name\":\"Bob\",\"age\":35,\"position\":\"architect\"}]")));

    client
        .get()
        .uri("/" + orgId + "/with-employees")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Organization.class)
        .value(
            body -> {
              assertThat(body.getName()).isEqualTo("MegaCorp");
              assertThat(body.getEmployees()).hasSize(2);
              assertThat(body.getEmployees())
                  .extracting("name")
                  .containsExactlyInAnyOrder("Alice", "Bob");
            });

    employeeStub.verify(
        getRequestedFor(urlPathMatching("/organization/" + orgId))
            .withHeader("Accept", equalTo("application/json")));
  }

  @TestConfiguration
  static class WireMockClientConfig {

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
