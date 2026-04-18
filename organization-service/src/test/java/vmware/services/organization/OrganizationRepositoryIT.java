package vmware.services.organization;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.stream.StreamSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.mongodb.test.autoconfigure.DataMongoTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.mongodb.MongoDBContainer;
import vmware.services.organization.model.Organization;
import vmware.services.organization.repository.OrganizationRepository;

/**
 * @DataMongoTest slice test for {@link OrganizationRepository}. {@code OrganizationRepository}
 * exposes only the inherited {@link org.springframework.data.repository.CrudRepository} surface, so
 * this test verifies round-trip persistence (save/findById/findAll/deleteAll) against a real
 * MongoDB Testcontainer, with no web/Spring Cloud Kubernetes context loaded.
 */
@DataMongoTest
@Testcontainers
@ActiveProfiles("test")
class OrganizationRepositoryIT {

  @Container @ServiceConnection static MongoDBContainer mongo = new MongoDBContainer("mongo:8.2.7");

  @Autowired OrganizationRepository repository;

  @BeforeEach
  void clean() {
    repository.deleteAll();
  }

  @Test
  void savePersistsAndAssignsId() {
    Organization saved = repository.save(new Organization("MegaCorp", "Main Street"));

    assertThat(saved.getId()).isNotBlank();
    assertThat(repository.findById(saved.getId()))
        .isPresent()
        .get()
        .satisfies(
            o -> {
              assertThat(o.getName()).isEqualTo("MegaCorp");
              assertThat(o.getAddress()).isEqualTo("Main Street");
            });
  }

  @Test
  void findAllReturnsAllPersistedOrganizations() {
    repository.save(new Organization("MegaCorp", "Main Street"));
    repository.save(new Organization("SmallCo", "Side Street"));

    List<Organization> all =
        StreamSupport.stream(repository.findAll().spliterator(), false).toList();

    assertThat(all)
        .hasSize(2)
        .extracting(Organization::getName)
        .containsExactlyInAnyOrder("MegaCorp", "SmallCo");
  }

  @Test
  void deleteAllRemovesEverything() {
    repository.save(new Organization("MegaCorp", "Main Street"));
    repository.save(new Organization("SmallCo", "Side Street"));
    repository.deleteAll();

    assertThat(repository.findAll()).isEmpty();
  }
}
