package vmware.services.department;

import static com.github.tomakehurst.wiremock.client.WireMock.aResponse;
import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.stubFor;
import static com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo;
import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
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
import vmware.services.department.client.EmployeeClient;
import vmware.services.department.model.Department;
import vmware.services.department.repository.DepartmentRepository;

/**
 * Integration test for the department-service cross-service fan-out endpoint {@code GET
 * /organization/{id}/with-employees}. Verifies the real {@link EmployeeClient} @HttpExchange wire
 * format against a WireMock-stubbed employee-service, and asserts that the nested response shape
 * embeds employees under each department.
 *
 * <p>Uses Testcontainers Mongo for the department repository + WireMock for the employee peer.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@AutoConfigureWireMock(port = 0)
@Testcontainers
@ActiveProfiles("test")
class DepartmentWithEmployeesIT {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.0.20");

  @Autowired TestRestTemplate restTemplate;

  @Autowired DepartmentRepository repository;

  /**
   * Replaces the {@code @LoadBalanced} {@code EmployeeClient} bean defined in {@code
   * RestClientConfig} with one pointing at the WireMock server (injected via {@code
   * wiremock.server.port}). Must be {@code @Primary} so Spring picks it over the production bean.
   */
  @TestConfiguration
  static class WireMockClientConfig {
    @Bean
    @Primary
    EmployeeClient wiremockEmployeeClient(
        @org.springframework.beans.factory.annotation.Value("${wiremock.server.port}") int port) {
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
  void shouldReturnDepartmentsWithEmbeddedEmployees() {
    Department engineering = new Department(1L, "Engineering");
    Department marketing = new Department(1L, "Marketing");
    Department saved1 = repository.save(engineering);
    Department saved2 = repository.save(marketing);

    // Stub the employee-service /department/{id} endpoint — this is the real path
    // that EmployeeClient.findByDepartment() issues under the covers.
    stubFor(
        get(urlEqualTo("/department/" + saved1.getId()))
            .willReturn(
                aResponse()
                    .withHeader("Content-Type", "application/json")
                    .withBody(
                        "[{\"id\":10,\"name\":\"Smith\",\"age\":25,\"position\":\"engineer\"}]")));
    stubFor(
        get(urlEqualTo("/department/" + saved2.getId()))
            .willReturn(
                aResponse()
                    .withHeader("Content-Type", "application/json")
                    .withBody("[]")));

    ResponseEntity<Department[]> response =
        restTemplate.getForEntity("/organization/1/with-employees", Department[].class);

    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(response.getBody()).hasSize(2);
    Department engResponse =
        response.getBody()[0].getId().equals(saved1.getId())
            ? response.getBody()[0]
            : response.getBody()[1];
    assertThat(engResponse.getName()).isEqualTo("Engineering");
    assertThat(engResponse.getEmployees()).hasSize(1);
    assertThat(engResponse.getEmployees().get(0).getName()).isEqualTo("Smith");
    assertThat(engResponse.getEmployees().get(0).getPosition()).isEqualTo("engineer");
  }
}
