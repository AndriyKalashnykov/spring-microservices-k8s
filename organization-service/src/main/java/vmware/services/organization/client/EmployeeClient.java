package vmware.services.organization.client;

import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.service.annotation.GetExchange;
import vmware.services.organization.model.Employee;

import java.util.List;

public interface EmployeeClient {
    @GetExchange("/organization/{organizationId}")
    List<Employee> findByOrganization(@PathVariable("organizationId") String organizationId);
}
