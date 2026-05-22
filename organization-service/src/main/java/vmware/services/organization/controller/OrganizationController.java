package vmware.services.organization.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import vmware.services.organization.client.DepartmentClient;
import vmware.services.organization.client.EmployeeClient;
import vmware.services.organization.model.Organization;
import vmware.services.organization.repository.OrganizationRepository;

@RestController
public class OrganizationController {

  private static final Logger LOGGER = LoggerFactory.getLogger(OrganizationController.class);

  @Autowired OrganizationRepository repository;

  @Autowired DepartmentClient departmentClient;

  @Autowired EmployeeClient employeeClient;

  @PostMapping
  public Organization add(@RequestBody Organization organization) {
    LOGGER.info("Organization add: {}", organization);
    return repository.save(organization);
  }

  @GetMapping
  public Iterable<Organization> findAll() {
    LOGGER.info("Organization find");
    return repository.findAll();
  }

  @GetMapping("/{id}")
  public Organization findById(@PathVariable("id") String id) {
    LOGGER.info("Organization find: id={}", id);
    return repository
        .findById(id)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Organization " + id));
  }

  @GetMapping("/{id}/with-departments")
  public Organization findByIdWithDepartments(@PathVariable("id") String id) {
    LOGGER.info("Organization find: id={}", id);
    Organization o = loadOrThrow(id);
    o.setDepartments(departmentClient.findByOrganization(o.getId()));
    return o;
  }

  @GetMapping("/{id}/with-departments-and-employees")
  public Organization findByIdWithDepartmentsAndEmployees(@PathVariable("id") String id) {
    LOGGER.info("Organization find: id={}", id);
    Organization o = loadOrThrow(id);
    o.setDepartments(departmentClient.findByOrganizationWithEmployees(o.getId()));
    return o;
  }

  @GetMapping("/{id}/with-employees")
  public Organization findByIdWithEmployees(@PathVariable("id") String id) {
    LOGGER.info("Organization find: id={}", id);
    Organization o = loadOrThrow(id);
    o.setEmployees(employeeClient.findByOrganization(o.getId()));
    return o;
  }

  /**
   * Load the organization or throw 404. Single source for the missing-id contract across {@code
   * /{id}/with-*} endpoints — short-circuits before any peer fan-out so a missing org never fires
   * downstream calls.
   */
  private Organization loadOrThrow(String id) {
    return repository
        .findById(id)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Organization " + id));
  }
}
