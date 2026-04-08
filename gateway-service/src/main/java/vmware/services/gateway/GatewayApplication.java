package vmware.services.gateway;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.ServiceInstance;
import org.springframework.cloud.client.discovery.DiscoveryClient;
import org.springframework.cloud.gateway.server.mvc.handler.HandlerFunctions;
import org.springframework.context.annotation.Bean;
import org.springframework.web.servlet.function.RouterFunction;
import org.springframework.web.servlet.function.ServerResponse;

import jakarta.annotation.PostConstruct;
import java.util.List;

import static org.springframework.cloud.gateway.server.mvc.filter.BeforeFilterFunctions.stripPrefix;
import static org.springframework.cloud.gateway.server.mvc.filter.LoadBalancerFilterFunctions.lb;
import static org.springframework.cloud.gateway.server.mvc.handler.GatewayRouterFunctions.route;
import static org.springframework.cloud.gateway.server.mvc.predicate.GatewayRequestPredicates.path;

@SpringBootApplication
public class GatewayApplication {

	private static final Logger LOGGER = LoggerFactory.getLogger(GatewayApplication.class);

	private static final String EMPLOYEE_SERVICE = "employee";
	private static final String DEPARTMENT_SERVICE = "department";
	private static final String ORGANIZATION_SERVICE = "organization";

	public static void main(String[] args) {
		SpringApplication.run(GatewayApplication.class, args);
	}

	@Autowired
	DiscoveryClient client;

	@PostConstruct
	public void init() {
		LOGGER.info("Services: {}", client.getServices());
		for (String svc : client.getServices()) {
			try {
				List<ServiceInstance> its = client.getInstances(svc);
				for (ServiceInstance it : its) {
					LOGGER.info("Instance: url={}:{}, id={}, service={}", it.getHost(), it.getPort(), it.getInstanceId(), it.getServiceId());
				}
			} catch (Exception ex) {
				LOGGER.warn("Failed to lookup instance for service {}: {}", svc, ex.toString());
			}
		}
	}

	@Bean
	public RouterFunction<ServerResponse> employeeRoute() {
		return route(EMPLOYEE_SERVICE)
				.route(path("/" + EMPLOYEE_SERVICE, "/" + EMPLOYEE_SERVICE + "/**"), HandlerFunctions.http())
				.before(stripPrefix(1))
				.filter(lb(EMPLOYEE_SERVICE))
				.build();
	}

	@Bean
	public RouterFunction<ServerResponse> departmentRoute() {
		return route(DEPARTMENT_SERVICE)
				.route(path("/" + DEPARTMENT_SERVICE, "/" + DEPARTMENT_SERVICE + "/**"), HandlerFunctions.http())
				.before(stripPrefix(1))
				.filter(lb(DEPARTMENT_SERVICE))
				.build();
	}

	@Bean
	public RouterFunction<ServerResponse> organizationRoute() {
		return route(ORGANIZATION_SERVICE)
				.route(path("/" + ORGANIZATION_SERVICE, "/" + ORGANIZATION_SERVICE + "/**"), HandlerFunctions.http())
				.before(stripPrefix(1))
				.filter(lb(ORGANIZATION_SERVICE))
				.build();
	}
}
