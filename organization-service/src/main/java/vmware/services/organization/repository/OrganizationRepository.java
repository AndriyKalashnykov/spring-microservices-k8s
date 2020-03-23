package vmware.services.organization.repository;

import org.springframework.data.repository.CrudRepository;
import vmware.services.organization.model.Organization;

public interface OrganizationRepository extends CrudRepository<Organization, String> {
	
}
