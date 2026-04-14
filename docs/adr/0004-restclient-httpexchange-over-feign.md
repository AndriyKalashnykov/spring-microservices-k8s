# ADR-0004: RestClient with `@HttpExchange` over OpenFeign

- **Status**: Accepted
- **Date**: 2026-04-08
- **Context**: Inter-service HTTP client selection

## Decision

Use Spring's native `RestClient` with `@HttpExchange` declarative interfaces for inter-service communication. Do not use OpenFeign.

## Context

Spring Cloud OpenFeign has been the default "declarative HTTP client" in Spring Cloud for years. Since Spring Framework 6 / Spring Boot 3, Spring itself ships a narrower, idiomatic equivalent: `@HttpExchange` annotations on a Java interface plus a `RestClient` / `WebClient` proxy factory. This is now the recommended path for new projects.

## Alternatives considered

| Option | Verdict |
|--------|---------|
| OpenFeign | Rejected — adds `spring-cloud-starter-openfeign` dependency, pulls in Netflix OSS libraries (Hystrix-adjacent code paths, even without circuit breakers enabled), and duplicates functionality the Spring core now provides. Feature-parity with `@HttpExchange` for this project's call patterns. |
| `WebClient` (reactive) directly | Rejected — the services are servlet-stack (Spring MVC + Tomcat). Introducing reactive types only for inter-service calls mixes execution models. |
| `RestTemplate` | Rejected — deprecated in favor of `RestClient` in Spring 6. |
| `RestClient` + `@HttpExchange` | **Chosen** — native to Spring, no extra starter dependency, matches the servlet stack, declarative interface for testability. |

## Consequences

- Inter-service clients are plain Java interfaces (`EmployeeClient`, `DepartmentClient`) with `@GetExchange` / `@PostExchange` methods. No boilerplate HTTP code in service classes.
- Load-balancing via Spring Cloud LoadBalancer works — the `RestClient.Builder` bean is `@LoadBalanced`, and the `@HttpExchange` interface uses service IDs (e.g., `http://employee/`) resolved at call time via the Kubernetes DiscoveryClient.
- One less Netflix OSS dependency in the graph. CVE exposure reduced accordingly.
- Fewer developers have direct `@HttpExchange` experience compared to Feign. Offset by the smaller API surface — the whole client is a 6-method interface.

## References

- `department-service/src/main/java/vmware/services/department/client/EmployeeClient.java`
- `organization-service/src/main/java/vmware/services/organization/client/{DepartmentClient,EmployeeClient}.java`
- Spring Framework reference: [HTTP Interface Clients](https://docs.spring.io/spring-framework/reference/integration/rest-clients.html#rest-http-interface)
