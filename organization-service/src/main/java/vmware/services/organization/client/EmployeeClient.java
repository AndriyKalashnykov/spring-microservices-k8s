package vmware.services.organization.client;

import java.util.List;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.service.annotation.GetExchange;
import vmware.services.organization.model.Employee;

public interface EmployeeClient {

  @GetExchange(value = "/organization/{organizationId}", accept = "application/json")
  List<Employee> findByOrganization(@PathVariable("organizationId") String organizationId);
}
