package vmware.services.department.config;

import org.springframework.cloud.client.loadbalancer.LoadBalanced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.support.RestClientAdapter;
import org.springframework.web.service.invoker.HttpServiceProxyFactory;
import vmware.services.department.client.EmployeeClient;

@Configuration
public class RestClientConfig {

	@Bean
	@LoadBalanced
	RestClient.Builder restClientBuilder() {
		return RestClient.builder();
	}

	@Bean
	EmployeeClient employeeClient(RestClient.Builder builder) {
		RestClient restClient = builder.baseUrl("http://employee").build();
		return HttpServiceProxyFactory.builderFor(RestClientAdapter.create(restClient))
			.build()
			.createClient(EmployeeClient.class);
	}

}
