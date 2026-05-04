package vmware.services.department.config;

import org.springframework.boot.restclient.autoconfigure.RestClientBuilderConfigurer;
import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.support.RestClientAdapter;
import org.springframework.web.service.invoker.HttpServiceProxyFactory;
import vmware.services.department.client.EmployeeClient;

@Configuration
public class RestClientConfig {

  /**
   * Apply Spring Boot's auto-configured RestClient customizers (including the Micrometer Tracing
   * observation that injects W3C `traceparent` on outbound requests) to OUR {@code @LoadBalanced}
   * builder. Without {@code configurer.configure(...)}, this returns a vanilla
   * {@code RestClient.builder()} that bypasses every auto-configured bean — silently breaks
   * distributed-trace propagation through {@code @HttpExchange} clients built from it.
   */
  @Bean
  @LoadBalanced
  RestClient.Builder restClientBuilder(RestClientBuilderConfigurer configurer) {
    return configurer.configure(RestClient.builder());
  }

  @Bean
  EmployeeClient employeeClient(RestClient.Builder builder) {
    RestClient restClient = builder.baseUrl("http://employee").build();
    return HttpServiceProxyFactory.builderFor(RestClientAdapter.create(restClient))
        .build()
        .createClient(EmployeeClient.class);
  }
}
