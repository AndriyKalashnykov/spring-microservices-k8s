package vmware.services.employee;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MongoDBContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import vmware.services.employee.model.Employee;
import vmware.services.employee.repository.EmployeeRepository;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@ActiveProfiles("test")
class EmployeeControllerTest {

    @Container
    @ServiceConnection
    static MongoDBContainer mongo = new MongoDBContainer("mongo:7.0");

    @Autowired
    TestRestTemplate restTemplate;

    @Autowired
    EmployeeRepository repository;

    @BeforeEach
    void setUp() {
        repository.deleteAll();
    }

    @Test
    void shouldCreateEmployee() {
        Employee emp = new Employee(1L, 1L, "Smith", 25, "engineer");
        ResponseEntity<Employee> response = restTemplate.postForEntity("/", emp, Employee.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getName()).isEqualTo("Smith");
        assertThat(response.getBody().getId()).isNotNull();
    }

    @Test
    void shouldListAllEmployees() {
        repository.save(new Employee(1L, 1L, "Smith", 25, "engineer"));
        repository.save(new Employee(1L, 1L, "Johns", 45, "manager"));

        ResponseEntity<Employee[]> response = restTemplate.getForEntity("/", Employee[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).hasSize(2);
    }

    @Test
    void shouldFindByDepartment() {
        repository.save(new Employee(1L, 1L, "Smith", 25, "engineer"));
        repository.save(new Employee(1L, 2L, "Jones", 30, "analyst"));

        ResponseEntity<Employee[]> response = restTemplate.getForEntity("/department/1", Employee[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).hasSize(1);
        assertThat(response.getBody()[0].getName()).isEqualTo("Smith");
    }

    @Test
    void shouldFindByOrganization() {
        repository.save(new Employee(1L, 1L, "Smith", 25, "engineer"));
        repository.save(new Employee(2L, 1L, "Jones", 30, "analyst"));

        ResponseEntity<Employee[]> response = restTemplate.getForEntity("/organization/1", Employee[].class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).hasSize(1);
        assertThat(response.getBody()[0].getName()).isEqualTo("Smith");
    }
}
