package vmware.services.organization;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MongoDBContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vmware.services.organization.client.DepartmentClient;
import vmware.services.organization.client.EmployeeClient;
import vmware.services.organization.model.Organization;
import vmware.services.organization.repository.OrganizationRepository;

import java.util.Collections;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@ActiveProfiles("test")
class OrganizationControllerTest {

	@Container
	@ServiceConnection
	static MongoDBContainer mongo = new MongoDBContainer("mongo:7.0");

	@Autowired
	TestRestTemplate restTemplate;

	@Autowired
	OrganizationRepository repository;

	@MockitoBean
	EmployeeClient employeeClient;

	@MockitoBean
	DepartmentClient departmentClient;

	@BeforeEach
	void setUp() {
		repository.deleteAll();
		when(employeeClient.findByOrganization(anyString())).thenReturn(Collections.emptyList());
		when(departmentClient.findByOrganization(anyString())).thenReturn(Collections.emptyList());
		when(departmentClient.findByOrganizationWithEmployees(anyString())).thenReturn(Collections.emptyList());
	}

	@Test
	void shouldCreateOrganization() {
		Organization org = new Organization("MegaCorp", "Main Street");
		ResponseEntity<Organization> response = restTemplate.postForEntity("/", org, Organization.class);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(response.getBody()).isNotNull();
		assertThat(response.getBody().getName()).isEqualTo("MegaCorp");
	}

	@Test
	void shouldListAllOrganizations() {
		repository.save(new Organization("MegaCorp", "Main Street"));
		repository.save(new Organization("SmallCo", "Side Street"));

		ResponseEntity<Organization[]> response = restTemplate.getForEntity("/", Organization[].class);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(response.getBody()).hasSize(2);
	}

	@Test
	void shouldFindById() {
		Organization saved = repository.save(new Organization("MegaCorp", "Main Street"));

		ResponseEntity<Organization> response = restTemplate.getForEntity("/" + saved.getId(), Organization.class);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(response.getBody().getName()).isEqualTo("MegaCorp");
	}

}
