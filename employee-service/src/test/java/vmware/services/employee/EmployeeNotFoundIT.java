package vmware.services.employee;

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
 * Locks the {@code GET /{id}} not-found contract for the employee service. The controller maps a
 * missing id to {@link org.springframework.web.server.ResponseStatusException} with {@code 404}
 * (rather than letting the repository's empty {@code Optional} surface as a 500). This test is the
 * integration-layer floor for that contract; e2e covers the same shape through the gateway.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
@Testcontainers
@ActiveProfiles("test")
class EmployeeNotFoundIT {

  @Container @ServiceConnection static MongoDBContainer mongo = new MongoDBContainer("mongo:8.3.2");

  @Autowired RestTestClient client;

  @Test
  void shouldReturn404WhenEmployeeIdIsUnknown() {
    client.get().uri("/unknown-employee-id").exchange().expectStatus().isNotFound();
  }
}
