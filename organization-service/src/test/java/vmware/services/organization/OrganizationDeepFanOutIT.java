package vmware.services.organization;

import static com.github.tomakehurst.wiremock.client.WireMock.aResponse;
import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.stubFor;
import static com.github.tomakehurst.wiremock.client.WireMock.urlPathMatching;
import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.cloud.contract.wiremock.AutoConfigureWireMock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.support.RestClientAdapter;
import org.springframework.web.service.invoker.HttpServiceProxyFactory;
import org.testcontainers.containers.MongoDBContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vmware.services.organization.client.DepartmentClient;
import vmware.services.organization.client.EmployeeClient;
import vmware.services.organization.model.Organization;
import vmware.services.organization.repository.OrganizationRepository;

/**
 * Integration test for the organization-service DEEP fan-out endpoint {@code GET
 * /{id}/with-departments-and-employees}. Verifies the real {@link DepartmentClient} and {@link
 * EmployeeClient} @HttpExchange wire formats against a WireMock-stubbed peer cluster (department +
 * employee services), and asserts the three-level response shape (org → departments →
 * employees).
 *
 * <p>Uses Testcontainers Mongo for the organization repository + WireMock for the downstream
 * peers. Both clients are repointed at WireMock via a {@code @TestConfiguration} that shadows the
 * {@code @LoadBalanced} beans from {@code RestClientConfig}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@AutoConfigureWireMock(port = 0)
@Testcontainers
@ActiveProfiles("test")
class OrganizationDeepFanOutIT {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.0.20");

  @Autowired TestRestTemplate restTemplate;

  @Autowired OrganizationRepository repository;

  /**
   * Replaces both {@code @LoadBalanced} clients with WireMock-pointed variants. Both downstream
   * "hosts" collapse onto the same WireMock server — the @HttpExchange path templates are
   * distinct, so stubs never collide.
   */
  @TestConfiguration
  static class WireMockClientConfig {
    @Bean
    @Primary
    DepartmentClient wiremockDepartmentClient(@Value("${wiremock.server.port}") int port) {
      RestClient restClient = RestClient.builder().baseUrl("http://localhost:" + port).build();
      return HttpServiceProxyFactory.builderFor(RestClientAdapter.create(restClient))
          .build()
          .createClient(DepartmentClient.class);
    }

    @Bean
    @Primary
    EmployeeClient wiremockEmployeeClient(@Value("${wiremock.server.port}") int port) {
      RestClient restClient = RestClient.builder().baseUrl("http://localhost:" + port).build();
      return HttpServiceProxyFactory.builderFor(RestClientAdapter.create(restClient))
          .build()
          .createClient(EmployeeClient.class);
    }
  }

  @BeforeEach
  void setUp() {
    repository.deleteAll();
  }

  @Test
  void shouldReturnOrganizationWithDepartmentsAndEmployees() {
    Organization saved = repository.save(new Organization("MegaCorp", "Main Street"));

    // department-service GET /organization/{id}/with-employees — returns departments each
    // already hydrated with employees (matches DepartmentClient.findByOrganizationWithEmployees).
    stubFor(
        get(urlPathMatching("/organization/" + saved.getId() + "/with-employees"))
            .willReturn(
                aResponse()
                    .withHeader("Content-Type", "application/json")
                    .withBody(
                        "[{\"id\":1,\"name\":\"Engineering\",\"employees\":["
                            + "{\"id\":10,\"name\":\"Smith\",\"age\":25,\"position\":\"engineer\"}"
                            + "]}]")));

    ResponseEntity<Organization> response =
        restTemplate.getForEntity(
            "/" + saved.getId() + "/with-departments-and-employees", Organization.class);

    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    Organization body = response.getBody();
    assertThat(body).isNotNull();
    assertThat(body.getName()).isEqualTo("MegaCorp");
    assertThat(body.getDepartments()).hasSize(1);
    assertThat(body.getDepartments().get(0).getName()).isEqualTo("Engineering");
    assertThat(body.getDepartments().get(0).getEmployees()).hasSize(1);
    assertThat(body.getDepartments().get(0).getEmployees().get(0).getName()).isEqualTo("Smith");
    assertThat(body.getDepartments().get(0).getEmployees().get(0).getPosition())
        .isEqualTo("engineer");
  }
}
