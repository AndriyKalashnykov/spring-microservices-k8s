package vmware.services.department;

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
import vmware.services.department.client.EmployeeClient;
import vmware.services.department.model.Department;
import vmware.services.department.repository.DepartmentRepository;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
class DepartmentControllerTest {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.0.20");

  @Autowired RestTestClient client;

  @Autowired DepartmentRepository repository;

  @MockitoBean EmployeeClient employeeClient;

  @BeforeEach
  void setUp() {
    repository.deleteAll();
    when(employeeClient.findByDepartment(anyString())).thenReturn(Collections.emptyList());
  }

  @Test
  void shouldCreateDepartment() {
    Department dept = new Department(1L, "Engineering");

    client
        .post()
        .uri("/")
        .bodyValue(dept)
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Department.class)
        .value(
            body -> {
              assertThat(body).isNotNull();
              assertThat(body.getName()).isEqualTo("Engineering");
            });
  }

  @Test
  void shouldListAllDepartments() {
    repository.save(new Department(1L, "Engineering"));
    repository.save(new Department(1L, "Marketing"));

    client
        .get()
        .uri("/")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Department[].class)
        .value(body -> assertThat(body).hasSize(2));
  }

  @Test
  void shouldFindByOrganization() {
    repository.save(new Department(1L, "Engineering"));
    repository.save(new Department(2L, "Marketing"));

    client
        .get()
        .uri("/organization/1")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Department[].class)
        .value(
            body -> {
              assertThat(body).hasSize(1);
              assertThat(body[0].getName()).isEqualTo("Engineering");
            });
  }
}
