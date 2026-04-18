package vmware.services.organization.client;

import java.util.List;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.service.annotation.GetExchange;
import vmware.services.organization.model.Department;

public interface DepartmentClient {

  @GetExchange(value = "/organization/{organizationId}", accept = "application/json")
  List<Department> findByOrganization(@PathVariable("organizationId") String organizationId);

  @GetExchange(value = "/organization/{organizationId}/with-employees", accept = "application/json")
  List<Department> findByOrganizationWithEmployees(
      @PathVariable("organizationId") String organizationId);
}
