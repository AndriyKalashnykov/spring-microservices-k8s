package vmware.services.employee;

import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.actuate.autoconfigure.metrics.MeterRegistryCustomizer;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import vmware.services.employee.repository.EmployeeRepository;

@SpringBootApplication
public class EmployeeApplication {

	@Autowired
    EmployeeRepository repository;

	public static void main(String[] args) {
		SpringApplication.run(EmployeeApplication.class, args);
	}

	@Bean
	MeterRegistryCustomizer meterRegistryCustomizer(MeterRegistry meterRegistry){
		return registry -> {
			meterRegistry.config()
					.commonTags("application", "employee");
		};
	}
}
