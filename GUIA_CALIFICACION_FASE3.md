# GUÍA DE CALIFICACIÓN — Delivereats Fase 3

**Estudiante:** José Alberto Alarcón Chigua  
**Carné:** 201346084  
**Repo:** https://github.com/iamjalberto/SA_PROYECTO_201346084  
**Tag:** `v3.0.0`  
**Rama principal:** `main`

---

## Rúbrica y Evidencias

### 1. Infraestructura como Código – Terraform (20 pts)

| Sub-criterio | Archivo(s) | Pts |
|---|---|---|
| Estructura de módulos, state y variables | `iac/terraform/main.tf`, `variables.tf`, `outputs.tf` | 5 |
| VPC, Subredes, Firewall y Frontend (Cloud Run) | `iac/terraform/modules/vpc/`, `iac/terraform/modules/cloud_run/` | 7 |
| GKE + Base de datos externa | `iac/terraform/modules/gke/`, `iac/terraform/modules/database/` | 8 |

**Backend remoto**: GCS bucket `delivereats-tfstate` (ver `main.tf` línea ~10)  
**Cloud SQL**: fuera del cluster, VPC peering privado (sin IP pública)

```bash
# Verificar
cd iac/terraform
terraform init -backend=false && terraform validate
```

---

### 2. Observabilidad y Monitoreo (20 pts)

#### ELK Stack (10 pts)
| Archivo | Descripción |
|---|---|
| `k8s/elk/01-elasticsearch.yaml` | Elasticsearch 8.12.2, StatefulSet, 10Gi PVC |
| `k8s/elk/02-kibana.yaml` | Kibana 8.12.2, Deployment + Service |
| `k8s/elk/03-fluentd-configmap.yaml` | fluent.conf con índices por microservicio |
| `k8s/elk/04-fluentd-daemonset.yaml` | DaemonSet + RBAC |
| `docs/dashboards/kibana-delivereats-dashboard.ndjson` | **Export del dashboard** |

**Dashboard Kibana** – Importar en: Stack Management → Saved Objects → Import  
Archivo: `docs/dashboards/kibana-delivereats-dashboard.ndjson`

#### Prometheus + Grafana (10 pts)
| Archivo | Descripción |
|---|---|
| `k8s/monitoring/01-prometheus-config.yaml` | `prometheus.yml` + 4 reglas de alerta |
| `k8s/monitoring/02-prometheus.yaml` | RBAC + Deployment |
| `k8s/monitoring/03-node-exporter.yaml` | DaemonSet Node Exporter |
| `k8s/monitoring/04-grafana.yaml` | Grafana con datasources preconfigurados |
| `docs/dashboards/grafana-delivereats-overview.json` | **Export del dashboard** |

**Dashboard Grafana** – Importar en: Dashboards → New → Import  
Archivo: `docs/dashboards/grafana-delivereats-overview.json`

**Alertas configuradas**: ServiceDown, HighLatency, HighErrorRate, PodCrashLooping

---

### 3. Gestión de Configuración y Testing (15 pts)

#### Ansible (5 pts)
| Archivo | Descripción |
|---|---|
| `iac/ansible/ansible.cfg` | Configuración Ansible |
| `iac/ansible/inventory/hosts.ini` | Inventario VM load-test |
| `iac/ansible/playbooks/setup-loadtest.yml` | Playbook principal |
| `iac/ansible/roles/loadtester/tasks/main.yml` | 8 tareas idempotentes |

```bash
# Ejecutar (requiere IP de la VM del output de Terraform)
LOAD_TEST_VM_IP=$(cd iac/terraform && terraform output -raw loadtest_vm_ip)
ansible-playbook -i iac/ansible/inventory/hosts.ini \
  iac/ansible/playbooks/setup-loadtest.yml \
  --private-key=~/.ssh/delivereats_loadtest \
  -e "ansible_host=$LOAD_TEST_VM_IP"
```

#### Smoke Tests (5 pts)
| Archivo | Descripción |
|---|---|
| `tests/smoke-test.sh` | Script bash, 4 suites, exit 0/1 |

```bash
BASE_URL=http://API_GATEWAY_URL ./tests/smoke-test.sh
```

**Suites**: (1) Health checks, (2) Auth flow, (3) Endpoints protegidos, (4) 401 sin token

#### Locust – Pruebas de Carga (5 pts)
| Archivo | Descripción |
|---|---|
| `tests/locustfile.py` | GuestUser 30% + RegisteredUser 70% |

```bash
# Ejecutar desde la VM de load-testing (configurada por Ansible)
locust -f /opt/delivereats-loadtest/locustfile.py \
  --host http://API_GATEWAY_URL \
  --headless --users 20 --spawn-rate 5 --run-time 2m \
  --html /tmp/locust-report-$(date +%Y%m%d).html
```

> El reporte HTML se genera durante la demostración en vivo.

---

### 4. CronJobs y Automatización (10 pts)

| Archivo | Descripción |
|---|---|
| `k8s/cronjob-order-reject.yaml` | CronJob `*/5 * * * *`, `concurrencyPolicy: Forbid` |
| `k8s/configmap-order-reject-script.yaml` | Script Node.js con anti-spam |

**Lógica**: rechaza órdenes `CREADA` > 60min → publica en `order.rejected` → anti-spam via tabla `order_notifications`

```bash
# Ver logs de ejecución
kubectl logs -n delivereats -l job-name=auto-reject-orders --tail=50
```

---

### 5. CI/CD Continuo (10 pts)

Archivo: `.github/workflows/ci-cd.yaml`

**Jobs agregados en Fase 3:**
- `terraform-validate`: `fmt -check` → `init -backend=false` → `validate` → **`plan`**
- `ansible-lint`: valida playbooks con `ansible-lint 24.2.0`

Ambos son prerrequisito de `build-and-push` y `deploy`.

---

### 6. Metodología y Documentación (10 pts)

| Entregable | Archivo |
|---|---|
| Tablero SCRUM | https://github.com/users/iamjalberto/projects/3 |
| Gestión ágil (sprints, backlog, retrospectivas) | `docs/GESTION_AGIL_FASE3.md` |
| Documentación técnica Fase 3 | `docs/DOCUMENTACION_FASE3.md` |
| Manual de Observabilidad | `docs/MANUAL_OBSERVABILIDAD.md` |
| Dashboards exportados | `docs/dashboards/` |

---

## Comandos de Despliegue – Orden Sugerido

```bash
# 1. Infraestructura
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars  # editar con valores reales
terraform init && terraform apply

# 2. Configurar VM de load-testing
ansible-playbook -i iac/ansible/inventory/hosts.ini \
  iac/ansible/playbooks/setup-loadtest.yml

# 3. Aplicar namespaces y manifests K8s
kubectl apply -f k8s/elk/
kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/cronjob-order-reject.yaml
kubectl apply -f k8s/configmap-order-reject-script.yaml

# 4. Smoke test
BASE_URL=http://$(kubectl get svc api-gateway -n delivereats -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):3000 \
  ./tests/smoke-test.sh

# 5. Prueba de carga (desde VM)
ssh user@LOAD_TEST_VM_IP "/opt/delivereats-loadtest/run-locust.sh"
```

---

## Penalizaciones a Verificar

| Condición | Penalización | Estado |
|---|---|---|
| Infraestructura creada manualmente | -100% | ✅ Todo via Terraform |
| Base de datos dentro del cluster K8s | -30% | ✅ Cloud SQL con VPC peering externo |
| Exceder 20 min en presentación | -15% | ⚠️ Preparar ensayo |
