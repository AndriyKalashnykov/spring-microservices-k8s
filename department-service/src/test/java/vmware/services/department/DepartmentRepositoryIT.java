package vmware.services.department;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.mongodb.test.autoconfigure.DataMongoTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.mongodb.MongoDBContainer;
import vmware.services.department.model.Department;
import vmware.services.department.repository.DepartmentRepository;

/**
 * @DataMongoTest slice test for {@link DepartmentRepository}. Exercises the custom {@code
 * findByOrganizationId} query against a real MongoDB Testcontainer without loading the full web /
 * Spring Cloud Kubernetes context.
 */
@DataMongoTest
@Testcontainers
@ActiveProfiles("test")
class DepartmentRepositoryIT {

  @Container @ServiceConnection
  static MongoDBContainer mongo = new MongoDBContainer("mongo:8.2.6");

  @Autowired DepartmentRepository repository;

  @BeforeEach
  void seed() {
    repository.deleteAll();
    repository.save(new Department(1L, "Engineering"));
    repository.save(new Department(1L, "Marketing"));
    repository.save(new Department(2L, "Finance"));
  }

  @Test
  void findByOrganizationIdReturnsOnlyMatchingOrganization() {
    assertThat(repository.findByOrganizationId(1L))
        .hasSize(2)
        .extracting(Department::getName)
        .containsExactlyInAnyOrder("Engineering", "Marketing");
  }

  @Test
  void findByOrganizationIdIsolatesTenants() {
    assertThat(repository.findByOrganizationId(2L))
        .hasSize(1)
        .extracting(Department::getName)
        .containsExactly("Finance");
  }

  @Test
  void findByOrganizationIdReturnsEmptyForUnknownOrganization() {
    assertThat(repository.findByOrganizationId(999L)).isEmpty();
  }
}
