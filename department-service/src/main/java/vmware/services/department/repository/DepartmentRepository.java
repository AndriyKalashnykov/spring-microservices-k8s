package vmware.services.department.repository;

import org.springframework.data.repository.CrudRepository;
import vmware.services.department.model.Department;

import java.util.List;

public interface DepartmentRepository extends CrudRepository<Department, String> {

	List<Department> findByOrganizationId(Long organizationId);
	
}
