package vmware.services.employee;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.data.mongo.DataMongoTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.mongodb.MongoDBContainer;
import vmware.services.employee.model.Employee;
import vmware.services.employee.repository.EmployeeRepository;

/**
 * @DataMongoTest slice test for {@link EmployeeRepository}. Exercises the custom finder methods
 * against a real MongoDB Testcontainer without loading the full web / Spring Cloud Kubernetes
 * context.
 */
@DataMongoTest
@Testcontainers
@ActiveProfiles("test")
class EmployeeRepositoryIT {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.0.20");

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
  void findByDepartmentIdReturnsOnlyMatchingDepartment() {
    assertThat(repository.findByDepartmentId(1L))
        .hasSize(2)
        .extracting(Employee::getName)
        .containsExactlyInAnyOrder("Alice", "Bob");
  }

  @Test
  void findByDepartmentIdReturnsEmptyForUnknownDepartment() {
    assertThat(repository.findByDepartmentId(999L)).isEmpty();
  }

  @Test
  void findByOrganizationIdReturnsAllEmployeesInOrganization() {
    assertThat(repository.findByOrganizationId(1L))
        .hasSize(3)
        .extracting(Employee::getName)
        .containsExactlyInAnyOrder("Alice", "Bob", "Carol");
  }

  @Test
  void findByOrganizationIdIsolatesTenants() {
    assertThat(repository.findByOrganizationId(2L))
        .hasSize(1)
        .extracting(Employee::getName)
        .containsExactly("Dave");
  }
}
