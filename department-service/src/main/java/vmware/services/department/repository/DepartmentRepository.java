package vmware.services.department.repository;

import java.util.List;
import org.springframework.data.repository.CrudRepository;
import vmware.services.department.model.Department;

public interface DepartmentRepository extends CrudRepository<Department, String> {

  List<Department> findByOrganizationId(Long organizationId);
}
