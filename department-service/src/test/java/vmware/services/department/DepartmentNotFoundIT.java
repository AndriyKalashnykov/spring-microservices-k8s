package vmware.services.department;

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

/**
 * Locks the {@code GET /{id}} not-found contract for the department service. Earlier the controller
 * called {@code repository.findById(id).get()}, which threw {@code NoSuchElementException} and
 * surfaced as a 500 — inconsistent with the employee-service contract. The controller now maps a
 * missing id to {@link org.springframework.web.server.ResponseStatusException} with {@code 404};
 * this test pins that behavior so the inconsistency cannot silently come back.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
class DepartmentNotFoundIT {

  @Container @ServiceConnection static MongoDBContainer mongo = new MongoDBContainer("mongo:8.3.3");

  @Autowired RestTestClient client;

  @Test
  void shouldReturn404WhenDepartmentIdIsUnknown() {
    client.get().uri("/unknown-department-id").exchange().expectStatus().isNotFound();
  }
}
