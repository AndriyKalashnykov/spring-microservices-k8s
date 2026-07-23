package vmware.services.employee;

import static org.assertj.core.api.Assertions.assertThat;

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

/**
 * Locks the {@code GET /{id}} contract for the employee service — both the happy path (200 with the
 * persisted body) and the missing-id path. The controller maps a missing id to {@link
 * org.springframework.web.server.ResponseStatusException} with {@code 404} (rather than letting the
 * repository's empty {@code Optional} surface as a 500). This test is the integration-layer floor
 * for that contract; e2e covers the same shape through the gateway.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
class EmployeeNotFoundIT {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.0.28");

  @Autowired RestTestClient client;

  @Autowired EmployeeRepository repository;

  @Test
  void shouldReturnEmployeeWhenIdExists() {
    repository.deleteAll();
    Employee saved = repository.save(new Employee(1L, 1L, "Alice", 30, "engineer"));
    String id = saved.getId();

    client
        .get()
        .uri("/" + id)
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Employee.class)
        .value(
            body -> {
              assertThat(body.getId()).isEqualTo(id);
              assertThat(body.getName()).isEqualTo("Alice");
              assertThat(body.getOrganizationId()).isEqualTo(1L);
              assertThat(body.getDepartmentId()).isEqualTo(1L);
              assertThat(body.getAge()).isEqualTo(30);
              assertThat(body.getPosition()).isEqualTo("engineer");
            });
  }

  @Test
  void shouldReturn404WhenEmployeeIdIsUnknown() {
    client.get().uri("/unknown-employee-id").exchange().expectStatus().isNotFound();
  }
}
