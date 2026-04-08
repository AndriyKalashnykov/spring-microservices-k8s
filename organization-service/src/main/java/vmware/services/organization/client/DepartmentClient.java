package vmware.services.organization.client;

import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.service.annotation.GetExchange;
import vmware.services.organization.model.Department;

import java.util.List;

public interface DepartmentClient {

	@GetExchange("/organization/{organizationId}")
	List<Department> findByOrganization(@PathVariable("organizationId") String organizationId);

	@GetExchange("/organization/{organizationId}/with-employees")
	List<Department> findByOrganizationWithEmployees(@PathVariable("organizationId") String organizationId);

}
