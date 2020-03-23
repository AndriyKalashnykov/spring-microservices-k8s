package vmware.services.employee.repository;

import org.springframework.data.repository.CrudRepository;
import vmware.services.employee.model.Employee;

import java.util.List;

public interface EmployeeRepository extends CrudRepository<Employee, String> {
	
	List<Employee> findByDepartmentId(Long departmentId);
	List<Employee> findByOrganizationId(Long organizationId);
	
}
