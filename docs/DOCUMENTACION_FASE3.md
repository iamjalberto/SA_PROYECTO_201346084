# Documentación Fase 3 – Delivereats
## DevOps, IaC y Observabilidad

**Curso**: Sistemas de Alto Rendimiento  
**Universidad**: San Carlos de Guatemala  
**Carnet**: 201346084  
**Fase**: 3  
**Período**: Marzo 19 – Abril 30, 2026  

---

## Índice

1. [Arquitectura General](#1-arquitectura-general)
2. [Infraestructura como Código – Terraform](#2-infraestructura-como-código--terraform)
3. [Automatización con Ansible](#3-automatización-con-ansible)
4. [CronJobs de Kubernetes](#4-cronjobs-de-kubernetes)
5. [Stack de Observabilidad ELK](#5-stack-de-observabilidad-elk)
6. [Monitoreo con Prometheus y Grafana](#6-monitoreo-con-prometheus-y-grafana)
7. [Pruebas de Carga con Locust](#7-pruebas-de-carga-con-locust)
8. [Pipeline CI/CD Actualizado](#8-pipeline-cicd-actualizado)

---

## 1. Arquitectura General

### Evolución respecto a Fase 2

En la Fase 2 se construyó la plataforma Delivereats como un conjunto de microservicios orquestados con Kubernetes en una VM GCP. La Fase 3 no agrega nuevas funcionalidades de negocio; en cambio, establece toda la infraestructura de productividad DevOps/SRE sobre GCP managed services.

### Diagrama de Arquitectura Fase 3

```
┌─────────────────────── GCP ──────────────────────────────────────────┐
│                                                                        │
│  ┌──────── VPC: delivereats-vpc ────────────────────────────────────┐ │
│  │                                                                    │ │
│  │   ┌──── Subnet: delivereats-subnet (10.0.0.0/20) ─────────────┐  │ │
│  │   │                                                              │  │ │
│  │   │   ┌─────────────── GKE Cluster ───────────────────────┐    │  │ │
│  │   │   │  Namespace: delivereats                            │    │  │ │
│  │   │   │    auth-service, restaurant-catalog-service        │    │  │ │
│  │   │   │    order-service, delivery-service                 │    │  │ │
│  │   │   │    notification-service, payment-service           │    │  │ │
│  │   │   │    api-gateway, frontend                           │    │  │ │
│  │   │   │    RabbitMQ, Redis                                 │    │  │ │
│  │   │   │    CronJob: auto-reject-orders                     │    │  │ │
│  │   │   │                                                    │    │  │ │
│  │   │   │  Namespace: logging                                │    │  │ │
│  │   │   │    Elasticsearch, Kibana, Fluentd                  │    │  │ │
│  │   │   │                                                    │    │  │ │
│  │   │   │  Namespace: monitoring                             │    │  │ │
│  │   │   │    Prometheus, Grafana, Node Exporter              │    │  │ │
│  │   │   └────────────────────────────────────────────────────┘    │  │ │
│  │   │                                                              │  │ │
│  │   │   ┌──── Cloud SQL (SQL Server 2019) ──────────────────┐    │  │ │
│  │   │   │  FUERA del cluster – VPC Peering                   │    │  │ │
│  │   │   │  delivereats-db (db-custom-4-15360)                │    │  │ │
│  │   │   └────────────────────────────────────────────────────┘    │  │ │
│  │   │                                                              │  │ │
│  │   │   ┌──── Compute Engine VM (load-test) ────────────────┐    │  │ │
│  │   │   │  e2-medium, Ubuntu 22.04                           │    │  │ │
│  │   │   │  Locust instalado via Ansible                      │    │  │ │
│  │   │   └────────────────────────────────────────────────────┘    │  │ │
│  │   └──────────────────────────────────────────────────────────────┘  │ │
│  │                                                                    │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│  ┌── Cloud Run ─────────────────────────────────────────────────────┐ │
│  │  frontend (serverless – opcional)                                  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Infraestructura como Código – Terraform

### Módulos

La infraestructura se organiza en cinco módulos Terraform ubicados en `iac/terraform/modules/`:

| Módulo       | Descripción                                              | Archivo principal            |
|--------------|----------------------------------------------------------|------------------------------|
| `vpc`        | VPC, subnet con secondary ranges (pods/services), 4 FW  | `modules/vpc/main.tf`        |
| `gke`        | Cluster GKE privado + node pool con autoscaling 1–5     | `modules/gke/main.tf`        |
| `database`   | Cloud SQL SQL Server 2019 (OUTSIDE cluster, VPC peering)| `modules/database/main.tf`   |
| `cloud_run`  | Cloud Run v2 para frontend serverless                   | `modules/cloud_run/main.tf`  |
| `compute`    | VM e2-medium para pruebas de carga con Locust           | `modules/compute/main.tf`    |

### Backend Remoto

El estado de Terraform se almacena en un bucket GCS para trabajo colaborativo y prevención de conflictos:

```hcl
backend "gcs" {
  bucket = "delivereats-tfstate"
  prefix = "terraform/state"
}
```

### Variables principales

| Variable              | Descripción                       | Valor por defecto     |
|-----------------------|-----------------------------------|-----------------------|
| `project_id`          | ID del proyecto GCP               | —                     |
| `region`              | Región GCP                        | `us-central1`         |
| `zone`                | Zona GCP                          | `us-central1-a`       |
| `cluster_name`        | Nombre del cluster GKE            | `delivereats-cluster` |
| `db_admin_password`   | Contraseña administrador SQL      | (sensitive)           |
| `loadtest_ssh_pubkey` | Clave pública SSH para VM         | —                     |

### Comandos de despliegue

```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con valores reales

terraform init
terraform fmt
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

### Consideración crítica – Cloud SQL fuera del cluster

Según el enunciado, la base de datos **debe** estar fuera del cluster de Kubernetes. Se implementó Cloud SQL (SQL Server 2019) con acceso a través de VPC peering privado. El modo de acceso es `PRIVATE` sin IP pública. El incumplimiento de este requisito conllevaría una penalización del 30%.

---

## 3. Automatización con Ansible

### Estructura

```
iac/ansible/
├── ansible.cfg
├── inventory/
│   └── hosts.ini
├── playbooks/
│   └── setup-loadtest.yml
└── roles/
    └── loadtester/
        ├── defaults/
        │   └── main.yml
        ├── tasks/
        │   └── main.yml
        └── templates/
            └── run-locust.sh.j2
```

### Rol `loadtester` – Tareas

El rol instala y configura Locust en la VM de pruebas de carga:

1. **Actualización de paquetes** – `apt update`
2. **Instalación de dependencias del sistema** – python3, python3-pip, python3-venv, git
3. **Creación de directorio de proyecto** – `/opt/delivereats-loadtest`
4. **Virtualenv de Python** – creado en `/opt/delivereats-loadtest/venv`
5. **Instalación de Locust 2.24** – dentro del virtualenv
6. **Copia del locustfile** – `tests/locustfile.py` → `/opt/delivereats-loadtest/`
7. **Copia del smoke test** – `tests/smoke-test.sh`
8. **Template del script de ejecución** – `run-locust.sh` con variables del inventario

### Ejecución

```bash
# Obtener la IP de la VM del output de Terraform
export LOAD_TEST_VM_IP=$(cd iac/terraform && terraform output -raw loadtest_vm_ip)

# Editar inventory o pasar como extra-var
ansible-playbook -i inventory/hosts.ini \
  playbooks/setup-loadtest.yml \
  --extra-vars "vm_ip=$LOAD_TEST_VM_IP" \
  --private-key=~/.ssh/delivereats_loadtest
```

---

## 4. CronJobs de Kubernetes

### Auto-Reject Orders

**Archivo**: `k8s/cronjob-order-reject.yaml`

El CronJob `auto-reject-orders` se ejecuta cada 5 minutos y rechaza automáticamente todas las órdenes en estado `CREADA` que tengan más de 60 minutos sin ser atendidas por un restaurante.

**Configuración**:
| Campo                | Valor                 |
|----------------------|-----------------------|
| Schedule             | `*/5 * * * *`         |
| concurrencyPolicy    | `Forbid`              |
| successfulJobsLimit  | 3                     |
| failedJobsLimit      | 1                     |
| activeDeadlineSeconds| 240                   |

**Lógica del script** (`k8s/configmap-order-reject-script.yaml`):

1. Consulta `ORDER` donde `status = 'CREADA'` y `created_at < NOW() - 60min`
2. Para cada orden encontrada:
   - Verifica en `order_notifications` si ya se notificó (anti-spam)
   - Actualiza `ORDER.status → 'RECHAZADA'`
   - Inserta en `order_notifications` el evento
   - Publica en RabbitMQ (`order.rejected`) para notificar al cliente
3. Reporta: `Rechazadas: X | Notificadas: X | Omitidas (anti-spam): X`

---

## 5. Stack de Observabilidad ELK

### Componentes

| Componente    | Imagen                           | Namespace | Puerto |
|---------------|----------------------------------|-----------|--------|
| Elasticsearch | `elasticsearch:8.12.2`           | logging   | 9200   |
| Kibana        | `kibana:8.12.2`                  | logging   | 5601   |
| Fluentd       | `fluent/fluentd-kubernetes-daemonset` | logging | 24224 |

### Arquitectura de Logs

```
Pods (stdout/stderr)
     │
     ▼
Fluentd DaemonSet
     │ (lee /var/log/containers/*.log)
     │ (enruta por app label)
     ▼
Elasticsearch (StatefulSet, 10Gi PVC)
     │
     ▼
Kibana (UI, Ingress: kibana.delivereats.local)
```

### Índices por microservicio

Fluentd crea índices separados por microservicio usando el label `app` del pod:

- `delivereats-auth-service.*`
- `delivereats-restaurant-catalog-service.*`
- `delivereats-order-service.*`
- `delivereats-api-gateway.*`
- `delivereats-*` (todos los demás)

### Despliegue

```bash
kubectl apply -f k8s/elk/00-namespace.yaml
kubectl apply -f k8s/elk/01-elasticsearch.yaml
kubectl apply -f k8s/elk/02-kibana.yaml
kubectl apply -f k8s/elk/03-fluentd-configmap.yaml
kubectl apply -f k8s/elk/04-fluentd-daemonset.yaml
kubectl apply -f k8s/elk/05-kibana-ingress.yaml
```

---

## 6. Monitoreo con Prometheus y Grafana

### Componentes

| Componente    | Imagen                      | Namespace  | Puerto |
|---------------|-----------------------------|------------|--------|
| Prometheus    | `prom/prometheus:v2.51.0`   | monitoring | 9090   |
| Grafana       | `grafana/grafana:10.4.0`    | monitoring | 3000   |
| Node Exporter | `prom/node-exporter:v1.7.0` | monitoring | 9100   |

### Scrape Targets de Prometheus

Prometheus recopila métricas de:

1. **kubernetes-apiservers** – métricas del API server
2. **kubernetes-nodes** – métricas de nodos vía kubelet
3. **node-exporter** – métricas de sistema (CPU, RAM, disco, red)
4. **delivereats-pods** – pods con anotación `prometheus.io/scrape: "true"`
5. **rabbitmq** – métricas de colas desde el endpoint de RabbitMQ

### Reglas de Alertas

| Alerta               | Condición                          | Severidad |
|----------------------|------------------------------------|-----------|
| ServiceDown          | endpoint down por > 1min           | critical  |
| HighLatency          | p95 latencia > 2s por > 5min       | warning   |
| HighErrorRate        | tasa de errores 5xx > 10% por > 5min | warning |
| PodCrashLooping      | restarts > 5 por > 2min            | warning   |

### Datasources en Grafana

Grafana viene preconfigurado con dos datasources:
- **Prometheus** (default) – `http://prometheus:9090`
- **Elasticsearch** – `http://elasticsearch.logging.svc.cluster.local:9200`

### Despliegue

```bash
kubectl apply -f k8s/monitoring/00-namespace.yaml
kubectl apply -f k8s/monitoring/01-prometheus-config.yaml
kubectl apply -f k8s/monitoring/02-prometheus.yaml
kubectl apply -f k8s/monitoring/03-node-exporter.yaml
kubectl apply -f k8s/monitoring/04-grafana.yaml
kubectl apply -f k8s/monitoring/05-monitoring-ingress.yaml
```

---

## 7. Pruebas de Carga con Locust

### Archivo: `tests/locustfile.py`

Implementa dos clases de usuarios con comportamientos diferenciados:

| Clase            | Peso | Comportamiento                                              |
|------------------|------|-------------------------------------------------------------|
| `GuestUser`      | 30%  | Solo navega: health, listado de restaurantes                |
| `RegisteredUser` | 70%  | Flujo completo: registro, login, restaurantes, FX, órdenes, wallet |

**Tareas de `RegisteredUser`**:
- `view_restaurants` (peso 3) – Listar y ver detalles
- `convert_currency` (peso 2) – Consultar FX (GTQ→USD, USD→GTQ)
- `place_order` (peso 1) – Crear orden completa con item aleatorio
- `check_wallet` (peso 2) – Consultar saldo de wallet

### Ejecución con Ansible

```bash
# En la VM de carga (configurada por Ansible)
/opt/delivereats-loadtest/run-locust.sh

# O manual headless
locust -f /opt/delivereats-loadtest/locustfile.py \
  --host http://API_GATEWAY_URL \
  --headless \
  --users 20 \
  --spawn-rate 5 \
  --run-time 2m \
  --html /tmp/locust-report.html
```

### Smoke Tests: `tests/smoke-test.sh`

Script bash que valida el flujo crítico antes/después de un despliegue:

- **Suite 1**: Health checks de todos los microservicios (6 endpoints)
- **Suite 2**: Registro de usuario → Login → Validación de token
- **Suite 3**: Endpoints protegidos con token válido (restaurantes, FX, wallet, órdenes)
- **Suite 4**: Endpoints protegidos sin token → deben retornar 401

Exit code: `0` si todo pasa, `1` si algún test falla.

---

## 8. Pipeline CI/CD Actualizado

### Archivo: `.github/workflows/ci-cd.yaml`

La Fase 3 agrega dos nuevos jobs al inicio del pipeline:

```
terraform-validate ──┐
                      ├── build-and-push ──── deploy
ansible-lint ─────────┤
test ─────────────────┤
test-python ──────────┘
```

### Job: `terraform-validate`

```yaml
steps:
  - Setup Terraform 1.7.5
  - terraform fmt -check -recursive
  - terraform init -backend=false
  - terraform validate
```

### Job: `ansible-lint`

```yaml
steps:
  - Setup Python 3.11
  - pip install ansible-lint==24.2.0
  - ansible-lint playbooks/setup-loadtest.yml
```

Ambos jobs son prerrequisito obligatorio para `build-and-push` y `deploy`.

---

## Estructura de Directorios – Fase 3

```
SA_PROYECTO_201346084/
├── iac/
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars.example
│   │   └── modules/
│   │       ├── vpc/
│   │       ├── gke/
│   │       ├── database/
│   │       ├── cloud_run/
│   │       └── compute/
│   └── ansible/
│       ├── ansible.cfg
│       ├── inventory/hosts.ini
│       ├── playbooks/setup-loadtest.yml
│       └── roles/loadtester/
├── k8s/
│   ├── cronjob-order-reject.yaml
│   ├── configmap-order-reject-script.yaml
│   ├── elk/           (00-05 manifests)
│   └── monitoring/    (00-05 manifests)
├── tests/
│   ├── locustfile.py
│   └── smoke-test.sh
└── docs/
    ├── DOCUMENTACION_FASE3.md
    ├── MANUAL_OBSERVABILIDAD.md
    ├── GESTION_AGIL_FASE3.md
    ├── locust-report.html
    ├── presentacion-fase3.html
    └── dashboards/
        ├── grafana-delivereats-overview.json
        └── kibana-delivereats-dashboard.ndjson
```

---

## 9. Casos de Uso Actualizados – Fase 3

La Fase 3 no introduce nuevos actores de negocio pero incorpora dos flujos nuevos: la **tarea automática de rechazo de órdenes** (CronJob) y las **operaciones de observabilidad** (consultadas por el operador SRE).

### Nuevos Casos de Uso

#### CU-F3-01: Rechazar Órdenes Abandonadas (CronJob)
| Campo | Descripción |
|---|---|
| **Actor** | Sistema (CronJob Kubernetes, ejecuta cada 5 min) |
| **Precondición** | Existen órdenes en estado `CREADA` con `created_at < NOW() - 60 min` |
| **Flujo principal** | 1. CronJob consulta DB por órdenes expiradas. 2. Para cada orden: verifica `order_notifications` (anti-spam). 3. Actualiza estado a `RECHAZADA`. 4. Publica evento `order.rejected` en RabbitMQ. 5. `notification-service` envía email al cliente. 6. Registra entrada en `order_notifications`. |
| **Excepción** | Si la orden ya tiene notificación de tipo `RECHAZO`, se omite (anti-spam). |
| **Postcondición** | Orden en estado `RECHAZADA`. Cliente notificado exactamente una vez. |

#### CU-F3-02: Consultar Métricas de Observabilidad (SRE)
| Campo | Descripción |
|---|---|
| **Actor** | Operador SRE |
| **Precondición** | Stack de monitoreo desplegado (Prometheus + Grafana). |
| **Flujo principal** | 1. SRE accede a Grafana (`/grafana`). 2. Selecciona dashboard "Delivereats Overview". 3. Visualiza uptime por servicio, request rate, latencia P95, error rate. 4. Si se dispara una alerta, revisa detalle en Alertmanager. |
| **Postcondición** | SRE puede tomar acción sobre el microservicio degradado. |

#### CU-F3-03: Consultar Logs Centralizados (SRE)
| Campo | Descripción |
|---|---|
| **Actor** | Operador SRE |
| **Precondición** | Stack ELK desplegado. Fluentd recolectando logs. |
| **Flujo principal** | 1. SRE accede a Kibana (`/kibana`). 2. Busca en índice `delivereats-*` por `level: error`. 3. Filtra por servicio y rango de tiempo. 4. Exporta logs relevantes para post-mortem. |
| **Postcondición** | Logs de error aislados y exportados. |

---

## 10. Diagrama Entidad–Relación Actualizado – Fase 3

La Fase 3 agrega una tabla al esquema existente de Fase 2: `order_notifications`, necesaria para el mecanismo anti-spam del CronJob.

```
┌─────────────────────────────────────────────────────────────────────┐
│  NOVEDADES FASE 3 (resaltadas con **)                               │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────┐          ┌────────────────────────────────────┐
│     orders       │          │  ** order_notifications **         │
├──────────────────┤  1 ─── N ├────────────────────────────────────┤
│ id         (PK)  │──────────│ id          (PK)                   │
│ customer_id      │          │ order_id    (FK → orders.id)       │
│ customer_email   │          │ type        VARCHAR(20)            │
│ restaurant_id    │          │             ('RECHAZO','CONFIRMADO')│
│ status           │          │ sent_at     TIMESTAMP              │
│   CREADA         │          │ channel     VARCHAR(10) ('EMAIL')  │
│   ACEPTADA       │          └────────────────────────────────────┘
│   RECHAZADA      │
│   ENTREGADA      │
│ created_at       │          Propósito: registra qué notificaciones
│ updated_at       │          ya fueron enviadas para evitar spam   
└──────────────────┘          (verificada antes de cada envío).    

 TABLAS HEREDADAS DE FASE 2 (sin cambios estructurales):
 ┌───────────┐  ┌────────────┐  ┌──────────────┐  ┌──────────┐
 │  users    │  │restaurants │  │ order_items  │  │ payments │
 └───────────┘  └────────────┘  └──────────────┘  └──────────┘
```

### DDL de la tabla nueva

```sql
-- Tabla anti-spam para CronJob de rechazo de órdenes
CREATE TABLE IF NOT EXISTS order_notifications (
  id         SERIAL PRIMARY KEY,
  order_id   INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  type       VARCHAR(20) NOT NULL CHECK (type IN ('RECHAZO', 'CONFIRMADO', 'ENTREGADO')),
  sent_at    TIMESTAMP NOT NULL DEFAULT NOW(),
  channel    VARCHAR(10) NOT NULL DEFAULT 'EMAIL',
  UNIQUE (order_id, type)   -- Garantía anti-spam a nivel de BD
);

CREATE INDEX idx_order_notif_order_id ON order_notifications(order_id);
```

> **Nota de consistencia**: la restricción `UNIQUE (order_id, type)` a nivel de base de datos actúa como segunda capa de anti-spam, complementando la verificación en código del CronJob.
