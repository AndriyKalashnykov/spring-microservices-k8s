package vmware.services.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.web.servlet.function.RouterFunction;

/**
 * Context-load smoke test. Exercises the same Spring Boot autoconfiguration path that runs in
 * production — Spring Cloud Gateway Server WebMVC, Spring Cloud LoadBalancer, and the
 * DiscoveryClient bean — and verifies the three route {@link RouterFunction} beans are wired.
 *
 * <p>Spring Cloud Kubernetes is disabled via {@code application-test.yml} so the test does not need
 * a real K8s API server; the LoadBalancer filter factory is still on the classpath and the route
 * beans are still constructed, which is what catches Spring Cloud Gateway autoconfig regressions.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
@ActiveProfiles("test")
class GatewayApplicationTests {

  @Autowired ApplicationContext context;

  @Test
  void contextLoads() {
    assertThat(context).isNotNull();
  }

  @Test
  void allThreeServiceRoutesAreRegistered() {
    assertThat(context.getBeansOfType(RouterFunction.class).keySet())
        .contains("employeeRoute", "departmentRoute", "organizationRoute");
  }
}
