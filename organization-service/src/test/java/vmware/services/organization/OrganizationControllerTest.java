package vmware.services.organization;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import java.util.Collections;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.client.RestTestClient;
import org.testcontainers.containers.MongoDBContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vmware.services.organization.client.DepartmentClient;
import vmware.services.organization.client.EmployeeClient;
import vmware.services.organization.model.Organization;
import vmware.services.organization.repository.OrganizationRepository;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
class OrganizationControllerTest {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.0.20");

  @Autowired RestTestClient client;

  @Autowired OrganizationRepository repository;

  @MockitoBean EmployeeClient employeeClient;

  @MockitoBean DepartmentClient departmentClient;

  @BeforeEach
  void setUp() {
    repository.deleteAll();
    when(employeeClient.findByOrganization(anyString())).thenReturn(Collections.emptyList());
    when(departmentClient.findByOrganization(anyString())).thenReturn(Collections.emptyList());
    when(departmentClient.findByOrganizationWithEmployees(anyString()))
        .thenReturn(Collections.emptyList());
  }

  @Test
  void shouldCreateOrganization() {
    Organization org = new Organization("MegaCorp", "Main Street");

    client
        .post()
        .uri("/")
        .body(org)
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Organization.class)
        .value(
            body -> {
              assertThat(body).isNotNull();
              assertThat(body.getName()).isEqualTo("MegaCorp");
            });
  }

  @Test
  void shouldListAllOrganizations() {
    repository.save(new Organization("MegaCorp", "Main Street"));
    repository.save(new Organization("SmallCo", "Side Street"));

    client
        .get()
        .uri("/")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Organization[].class)
        .value(body -> assertThat(body).hasSize(2));
  }

  @Test
  void shouldFindById() {
    Organization saved = repository.save(new Organization("MegaCorp", "Main Street"));

    client
        .get()
        .uri("/" + saved.getId())
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Organization.class)
        .value(body -> assertThat(body.getName()).isEqualTo("MegaCorp"));
  }
}
