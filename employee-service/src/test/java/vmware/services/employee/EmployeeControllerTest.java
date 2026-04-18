package vmware.services.employee;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.client.RestTestClient;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.mongodb.MongoDBContainer;
import vmware.services.employee.model.Employee;
import vmware.services.employee.repository.EmployeeRepository;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
class EmployeeControllerTest {

  @Container @ServiceConnection static MongoDBContainer mongo = new MongoDBContainer("mongo:8.2.7");

  @Autowired RestTestClient client;

  @Autowired EmployeeRepository repository;

  @BeforeEach
  void setUp() {
    repository.deleteAll();
  }

  @Test
  void shouldCreateEmployee() {
    Employee emp = new Employee(1L, 1L, "Smith", 25, "engineer");

    client
        .post()
        .uri("/")
        .body(emp)
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Employee.class)
        .value(
            body -> {
              assertThat(body).isNotNull();
              assertThat(body.getName()).isEqualTo("Smith");
              assertThat(body.getId()).isNotNull();
            });
  }

  @Test
  void shouldListAllEmployees() {
    repository.save(new Employee(1L, 1L, "Smith", 25, "engineer"));
    repository.save(new Employee(1L, 1L, "Johns", 45, "manager"));

    client
        .get()
        .uri("/")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Employee[].class)
        .value(body -> assertThat(body).hasSize(2));
  }

  @Test
  void shouldFindByDepartment() {
    repository.save(new Employee(1L, 1L, "Smith", 25, "engineer"));
    repository.save(new Employee(1L, 2L, "Jones", 30, "analyst"));

    client
        .get()
        .uri("/department/1")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Employee[].class)
        .value(
            body -> {
              assertThat(body).hasSize(1);
              assertThat(body[0].getName()).isEqualTo("Smith");
            });
  }

  @Test
  void shouldFindByOrganization() {
    repository.save(new Employee(1L, 1L, "Smith", 25, "engineer"));
    repository.save(new Employee(2L, 1L, "Jones", 30, "analyst"));

    client
        .get()
        .uri("/organization/1")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Employee[].class)
        .value(
            body -> {
              assertThat(body).hasSize(1);
              assertThat(body[0].getName()).isEqualTo("Smith");
            });
  }
}
