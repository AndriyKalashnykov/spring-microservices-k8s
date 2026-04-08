package vmware.services.department;

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
import vmware.services.department.client.EmployeeClient;
import vmware.services.department.model.Department;
import vmware.services.department.repository.DepartmentRepository;

import java.util.Collections;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@ActiveProfiles("test")
class DepartmentControllerTest {

    @Container
    @ServiceConnection
    static MongoDBContainer mongo = new MongoDBContainer("mongo:7.0");

    @Autowired
    TestRestTemplate restTemplate;

    @Autowired
    DepartmentRepository repository;

    @MockitoBean
    EmployeeClient employeeClient;

    @BeforeEach
    void setUp() {
        repository.deleteAll();
        when(employeeClient.findByDepartment(anyString())).thenReturn(Collections.emptyList());
    }

    @Test
    void shouldCreateDepartment() {
        Department dept = new Department(1L, "Engineering");
        ResponseEntity<Department> response = restTemplate.postForEntity("/", dept, Department.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getName()).isEqualTo("Engineering");
    }

    @Test
    void shouldListAllDepartments() {
        repository.save(new Department(1L, "Engineering"));
        repository.save(new Department(1L, "Marketing"));

        ResponseEntity<Department[]> response = restTemplate.getForEntity("/", Department[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).hasSize(2);
    }

    @Test
    void shouldFindByOrganization() {
        repository.save(new Department(1L, "Engineering"));
        repository.save(new Department(2L, "Marketing"));

        ResponseEntity<Department[]> response = restTemplate.getForEntity("/organization/1", Department[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).hasSize(1);
        assertThat(response.getBody()[0].getName()).isEqualTo("Engineering");
    }
}
