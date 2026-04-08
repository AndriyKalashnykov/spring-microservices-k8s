package vmware.services.gateway;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.ServiceInstance;
import org.springframework.cloud.client.discovery.DiscoveryClient;

import jakarta.annotation.PostConstruct;
import java.util.List;

@SpringBootApplication
public class GatewayApplication {

	private static final Logger LOGGER = LoggerFactory.getLogger(GatewayApplication.class);

	public static void main(String[] args) {
		SpringApplication.run(GatewayApplication.class, args);
	}

	@Autowired
	DiscoveryClient client;

	@PostConstruct
	public void init() {
		LOGGER.info("Services: {}", client.getServices());

		// loop through details on every service for logging purposes
		for (String svc : client.getServices()) {
			try {
				// TODO(joshrosso): temporary workaround as getInstances will throw an exception when an endpoint port is
				// not set. See: https://github.com/spring-cloud/spring-cloud-kubernetes/issues/513
				List<ServiceInstance> its = client.getInstances(svc);
				for (ServiceInstance it : its) {
					LOGGER.info("Instance: url={}:{}, id={}, service={}", it.getHost(), it.getPort(), it.getInstanceId(), it.getServiceId());
				}
			} catch (Exception ex) {
				LOGGER.warn("Failed to lookup instance due to endpoint not specifying port for service {}. Exception: {}" + svc, ex.toString());
			}
		}

	}
}
