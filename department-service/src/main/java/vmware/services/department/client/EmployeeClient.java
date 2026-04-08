package vmware.services.department.client;

import java.util.List;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.service.annotation.GetExchange;
import vmware.services.department.model.Employee;

public interface EmployeeClient {

  @GetExchange("/department/{departmentId}")
  List<Employee> findByDepartment(@PathVariable("departmentId") String departmentId);
}
