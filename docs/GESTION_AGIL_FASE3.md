# Gestión Ágil – Fase 3 Delivereats
## Metodología SCRUM

**Proyecto**: Delivereats – Fase 3 (DevOps & Observabilidad)  
**Carnet**: 201346084  
**Período**: 19 de marzo – 23 de abril de 2026  
**Tablero ágil**: https://github.com/users/iamjalberto/projects/3

---

## Product Backlog – Fase 3

| ID   | Historia de Usuario | Criterios de Aceptación | Puntos | Sprint |
|------|---------------------|------------------------|--------|--------|
| PB-01 | Como DevOps, necesito que toda la infraestructura de GCP se provisione mediante Terraform, para eliminar la creación manual y tener reproducibilidad. | Módulos vpc, gke, database, cloud_run, compute creados. `terraform plan` sin errores. | 13 | Sprint 1 |
| PB-02 | Como SRE, necesito que la VM de pruebas de carga se configure automáticamente con Ansible, para poder ejecutar Locust sin instalación manual. | Ansible role idempotente. Locust instalado. Script ejecutable. | 8 | Sprint 1 |
| PB-03 | Como operador, necesito un CronJob que rechace órdenes abandonadas (+60min) automáticamente, para mantener la consistencia de datos. | CronJob cada 5min. Anti-spam funcional. Logs de conteo. | 5 | Sprint 2 |
| PB-04 | Como SRE, necesito el Stack ELK centralizado para ver logs de todos los microservicios en Kibana, con índices separados por servicio. | Elasticsearch corriendo. Fluentd recolectando. Kibana con dashboard funcional. | 13 | Sprint 2 |
| PB-05 | Como SRE, necesito Prometheus + Grafana con alertas configuradas, para detectar degradaciones del servicio en tiempo real. | Métricas de nodos y pods disponibles. 4 alertas definidas. Dashboard importable. | 8 | Sprint 3 |
| PB-06 | Como QA, necesito smoke tests automatizados que validen el flujo crítico, para integrarlos al pipeline de CI/CD. | smoke-test.sh corre en CI. Exit 0/1 correcto. Las 4 suites pasan. | 5 | Sprint 3 |
| PB-07 | Como QA, necesito pruebas de carga con Locust que simulen tráfico real por 2 minutos, para validar el comportamiento del sistema bajo presión. | locustfile.py con GuestUser + RegisteredUser. Reporte HTML generado. | 8 | Sprint 3 |
| PB-08 | Como DevOps, necesito que el pipeline de CI/CD valide Terraform y Ansible en cada push, para prevenir configuración inválida en main. | Jobs terraform-validate y ansible-lint agregados. Bloquean build si fallan. | 3 | Sprint 3 |
| PB-09 | Como equipo, necesito documentación completa del sistema de observabilidad, para que cualquier miembro pueda operar y mantener el stack. | DOCUMENTACION_FASE3.md + MANUAL_OBSERVABILIDAD.md completos. | 3 | Sprint 3 |

**Total puntos**: 66

---

## Sprints

### Sprint 1 – Infraestructura Base
**Fecha**: 19 mar – 28 mar 2026  
**Objetivo**: Toda la infraestructura de GCP provisionada mediante Terraform. VM de load-testing configurada con Ansible.

| Tarea | Estado | Responsable |
|-------|--------|-------------|
| Módulo Terraform VPC + Firewall | ✅ Done | 201346084 |
| Módulo Terraform GKE (cluster + node pool) | ✅ Done | 201346084 |
| Módulo Terraform Cloud SQL (MSSQL 2019) | ✅ Done | 201346084 |
| Módulo Terraform Cloud Run (frontend) | ✅ Done | 201346084 |
| Módulo Terraform Compute Engine (load-test VM) | ✅ Done | 201346084 |
| Backend remoto GCS para estado | ✅ Done | 201346084 |
| Ansible role loadtester (8 tareas) | ✅ Done | 201346084 |
| Ansible inventory + playbook + template | ✅ Done | 201346084 |

**Sprint Review**: Todos los módulos Terraform creados y validados (`terraform validate` pasa). Ansible configura la VM en un solo comando. Commit `feat(iac)` y `feat(ansible)` realizados dentro del sprint.

**Sprint Retrospective**:  
- ✅ **Bien**: Separación en módulos facilita mantenimiento.  
- ⚠️ **Mejorar**: El módulo database requirió investigación extra sobre VPC peering privado para cumplir el requisito "fuera del cluster".

---

### Sprint 2 – Automatización y Logs
**Fecha**: 29 mar – 10 abr 2026  
**Objetivo**: CronJob de negocio funcionando. Stack ELK recolectando logs de todos los microservicios.

| Tarea | Estado | Responsable |
|-------|--------|-------------|
| CronJob `auto-reject-orders` (YAML) | ✅ Done | 201346084 |
| ConfigMap con script Node.js + anti-spam | ✅ Done | 201346084 |
| Namespace `logging` | ✅ Done | 201346084 |
| Elasticsearch StatefulSet (10Gi PVC) | ✅ Done | 201346084 |
| Kibana Deployment + Ingress | ✅ Done | 201346084 |
| Fluentd ConfigMap (fluent.conf) | ✅ Done | 201346084 |
| Fluentd DaemonSet + RBAC | ✅ Done | 201346084 |
| Dashboard Kibana (exportación NDJSON) | ✅ Done | 201346084 |

**Sprint Review**: CronJob rechaza órdenes correctamente con lógica anti-spam verificada en logs. Fluentd crea índices `delivereats-{service}.*` en Elasticsearch. Kibana muestra logs en tiempo real filtrados por microservicio.

**Sprint Retrospective**:  
- ✅ **Bien**: Índices por microservicio facilitan el debugging.  
- ⚠️ **Mejorar**: El `vm.max_map_count` de Elasticsearch requiere configuración de nodo, documentado en el manual.

---

### Sprint 3 – Métricas, Tests y CI/CD
**Fecha**: 11 abr – 22 abr 2026  
**Objetivo**: Stack de monitoreo completo. Tests de carga automatizados. Pipeline validado.

| Tarea | Estado | Responsable |
|-------|--------|-------------|
| Namespace `monitoring` | ✅ Done | 201346084 |
| Prometheus ConfigMap (prometheus.yml + 4 alertas) | ✅ Done | 201346084 |
| Prometheus RBAC + Deployment | ✅ Done | 201346084 |
| Node Exporter DaemonSet | ✅ Done | 201346084 |
| Grafana Deployment + datasources preconfigurados | ✅ Done | 201346084 |
| Ingress para Grafana y Prometheus | ✅ Done | 201346084 |
| Dashboard Grafana (exportación JSON) | ✅ Done | 201346084 |
| `tests/locustfile.py` (GuestUser + RegisteredUser) | ✅ Done | 201346084 |
| `tests/smoke-test.sh` (4 suites) | ✅ Done | 201346084 |
| CI/CD: jobs terraform-validate + terraform plan | ✅ Done | 201346084 |
| CI/CD: job ansible-lint | ✅ Done | 201346084 |
| DOCUMENTACION_FASE3.md | ✅ Done | 201346084 |
| MANUAL_OBSERVABILIDAD.md | ✅ Done | 201346084 |
| Tag v3.0.0 | ✅ Done | 201346084 |

**Sprint Review**: Sistema completo. Prometheus scrape activo en 5 targets. Grafana muestra latencia P95, error rate y CPU/memoria. Locust simula 20 usuarios concurrentes con dos perfiles de comportamiento. Smoke tests integrados al pipeline.

**Sprint Retrospective**:  
- ✅ **Bien**: Grafana con datasources preconfigurados elimina setup manual en cada despliegue.  
- ✅ **Bien**: `continue-on-error: true` en terraform plan permite que el job report el plan sin bloquear por falta de credenciales en PRs externas.

---

## Definición de "Done" (DoD)

Para que una tarea se marque como completada debe cumplir:

1. ✅ Código/YAML escrito y revisado
2. ✅ Commiteado con mensaje convencional (`feat/fix/docs`)
3. ✅ Validado con herramienta correspondiente (`terraform validate`, `kubectl apply --dry-run`, `ansible-lint`)
4. ✅ Documentado (en DOCUMENTACION_FASE3.md o MANUAL_OBSERVABILIDAD.md según aplique)

---

## Velocidad del Equipo

| Sprint | Puntos planeados | Puntos completados | Velocidad |
|--------|-----------------|-------------------|-----------|
| Sprint 1 | 21 | 21 | 100% |
| Sprint 2 | 18 | 18 | 100% |
| Sprint 3 | 27 | 27 | 100% |
| **Total** | **66** | **66** | **100%** |
