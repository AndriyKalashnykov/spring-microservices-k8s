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

/**
 * Controller-layer integration test for the foreign-key finder endpoints — {@code GET
 * /department/{id}} and {@code GET /organization/{id}}. {@link EmployeeRepositoryIT} exercises the
 * same finders at the repository slice; this test pins the HTTP contract (path, media type,
 * return-shape) end-to-end through the controller, so a change to the controller route or
 * response-binding cannot regress silently.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
class EmployeeFinderIT {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.0.26");

  @Autowired RestTestClient client;

  @Autowired EmployeeRepository repository;

  @BeforeEach
  void seed() {
    repository.deleteAll();
    repository.save(new Employee(1L, 1L, "Alice", 30, "engineer"));
    repository.save(new Employee(1L, 1L, "Bob", 35, "architect"));
    repository.save(new Employee(1L, 2L, "Carol", 28, "manager"));
    repository.save(new Employee(2L, 3L, "Dave", 40, "director"));
  }

  @Test
  void shouldReturnEmployeesByDepartmentId() {
    client
        .get()
        .uri("/department/1")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Employee[].class)
        .value(
            body ->
                assertThat(body)
                    .extracting(Employee::getName)
                    .containsExactlyInAnyOrder("Alice", "Bob"));
  }

  @Test
  void shouldReturnEmptyArrayForUnknownDepartmentId() {
    client
        .get()
        .uri("/department/999")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Employee[].class)
        .value(body -> assertThat(body).isEmpty());
  }

  @Test
  void shouldReturnEmployeesByOrganizationId() {
    client
        .get()
        .uri("/organization/1")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Employee[].class)
        .value(
            body ->
                assertThat(body)
                    .extracting(Employee::getName)
                    .containsExactlyInAnyOrder("Alice", "Bob", "Carol"));
  }

  @Test
  void shouldIsolateTenantsByOrganizationId() {
    client
        .get()
        .uri("/organization/2")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody(Employee[].class)
        .value(body -> assertThat(body).extracting(Employee::getName).containsExactly("Dave"));
  }
}
