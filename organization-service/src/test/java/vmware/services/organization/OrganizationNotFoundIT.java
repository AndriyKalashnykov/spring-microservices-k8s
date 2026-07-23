package vmware.services.organization;

import static com.github.tomakehurst.wiremock.client.WireMock.anyRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.anyUrl;
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
 * Locks the not-found contract across every {@code GET /{id}} endpoint on the organization service.
 * Earlier {@code findById} called {@code .get()} (NoSuchElementException → 500) and the three
 * {@code /{id}/with-*} endpoints {@code return null} when the org was missing (200 with a {@code
 * null} body — semantically wrong). Each now throws {@link
 * org.springframework.web.server.ResponseStatusException} with {@code 404}.
 *
 * <p>The peer WireMock stubs are present specifically so the test can assert <em>zero</em> requests
 * were issued — the controller MUST short-circuit on the missing org before any fan-out.
 */
@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
    properties = "spring.main.allow-bean-definition-overriding=true")
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
@Import(OrganizationNotFoundIT.WireMockClientsConfig.class)
class OrganizationNotFoundIT {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.0.28");

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
  void shouldReturnOrganizationOnFindByIdWhenIdExists() {
    Organization saved = repository.save(new Organization("MegaCorp", "Main Street"));
    String orgId = saved.getId();

    client
        .get()
        .uri("/" + orgId)
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Organization.class)
        .value(
            body -> {
              assertThat(body.getId()).isEqualTo(orgId);
              assertThat(body.getName()).isEqualTo("MegaCorp");
              assertThat(body.getAddress()).isEqualTo("Main Street");
            });

    // Plain GET /{id} performs no fan-out — neither peer is touched.
    departmentStub.verify(0, anyRequestedFor(anyUrl()));
    employeeStub.verify(0, anyRequestedFor(anyUrl()));
  }

  @Test
  void shouldReturn404OnFindByIdWhenOrgIsUnknown() {
    client.get().uri("/unknown-org-id").exchange().expectStatus().isNotFound();
  }

  @Test
  void shouldReturn404OnWithDepartmentsWhenOrgIsUnknownAndNotCallPeer() {
    client.get().uri("/unknown-org-id/with-departments").exchange().expectStatus().isNotFound();

    // The controller must short-circuit before the department peer call.
    departmentStub.verify(0, anyRequestedFor(anyUrl()));
  }

  @Test
  void shouldReturn404OnWithEmployeesWhenOrgIsUnknownAndNotCallPeer() {
    client.get().uri("/unknown-org-id/with-employees").exchange().expectStatus().isNotFound();

    employeeStub.verify(0, anyRequestedFor(anyUrl()));
  }

  @Test
  void shouldReturn404OnWithDepartmentsAndEmployeesWhenOrgIsUnknownAndNotCallPeer() {
    client
        .get()
        .uri("/unknown-org-id/with-departments-and-employees")
        .exchange()
        .expectStatus()
        .isNotFound();

    // Deepest fan-out must short-circuit on the missing org — neither peer is touched.
    departmentStub.verify(0, anyRequestedFor(anyUrl()));
    employeeStub.verify(0, anyRequestedFor(anyUrl()));
  }

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
