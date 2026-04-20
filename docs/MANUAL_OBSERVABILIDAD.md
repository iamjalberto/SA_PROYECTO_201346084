# Manual de Observabilidad – Delivereats
## Guía de Instalación, Configuración y Uso

**Fase 3 – Sistemas de Alto Rendimiento**  
**Universidad San Carlos de Guatemala**  
**Carnet**: 201346084

---

## Índice

1. [Prerrequisitos](#1-prerrequisitos)
2. [Stack ELK – Instalación](#2-stack-elk--instalación)
3. [Stack ELK – Configuración de Kibana](#3-stack-elk--configuración-de-kibana)
4. [Prometheus – Instalación y Configuración](#4-prometheus--instalación-y-configuración)
5. [Grafana – Instalación y Dashboards](#5-grafana--instalación-y-dashboards)
6. [Alertas](#6-alertas)
7. [Acceso a los Servicios](#7-acceso-a-los-servicios)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Prerrequisitos

### Herramientas necesarias

```bash
# kubectl configurado apuntando al cluster GKE
kubectl cluster-info

# Verificar namespaces del proyecto
kubectl get namespaces | grep -E "delivereats|logging|monitoring"
```

### Almacenamiento

El cluster GKE debe tener un StorageClass disponible. Si usa GKE estándar, `standard-rwo` ya está disponible. Verificar:

```bash
kubectl get storageclass
```

Si Elasticsearch necesita un StorageClass diferente, editar `k8s/elk/01-elasticsearch.yaml`:

```yaml
storageClassName: standard-rwo   # cambiar según disponible
```

---

## 2. Stack ELK – Instalación

### Orden de despliegue

**Importante**: respetar el orden para garantizar dependencias.

```bash
# 1. Crear namespace
kubectl apply -f k8s/elk/00-namespace.yaml

# 2. Desplegar Elasticsearch (StatefulSet + PVC)
kubectl apply -f k8s/elk/01-elasticsearch.yaml

# Esperar a que Elasticsearch esté listo (puede tomar 2-3 minutos)
kubectl rollout status statefulset/elasticsearch -n logging --timeout=300s

# 3. Desplegar Kibana
kubectl apply -f k8s/elk/02-kibana.yaml

# 4. ConfigMap de Fluentd (debe existir antes del DaemonSet)
kubectl apply -f k8s/elk/03-fluentd-configmap.yaml

# 5. DaemonSet de Fluentd con RBAC
kubectl apply -f k8s/elk/04-fluentd-daemonset.yaml

# 6. Ingress para Kibana (opcional; requiere Ingress Controller)
kubectl apply -f k8s/elk/05-kibana-ingress.yaml
```

### Verificar el estado

```bash
# Pods en el namespace logging
kubectl get pods -n logging

# Esperado:
# NAME                     READY   STATUS    RESTARTS
# elasticsearch-0          1/1     Running   0
# kibana-XXXXXXXXX-XXXXX   1/1     Running   0
# fluentd-XXXXX (x N nodos) 1/1   Running   0
```

### Verificar que Elasticsearch recibe logs

```bash
# Port-forward temporal
kubectl port-forward svc/elasticsearch -n logging 9200:9200 &

# Ver índices creados (deberían aparecer tras ~60s con pods activos)
curl -s http://localhost:9200/_cat/indices?v | grep delivereats

# Respuesta esperada (ejemplo):
# green open delivereats-auth-service.2026.04.01    ...
# green open delivereats-order-service.2026.04.01   ...
```

---

## 3. Stack ELK – Configuración de Kibana

### Acceso a Kibana

```bash
# Port-forward para acceso local
kubectl port-forward svc/kibana -n logging 5601:5601

# Abrir: http://localhost:5601
# O via Ingress: http://kibana.delivereats.local (con DNS configurado)
```

### Crear Data View (Index Pattern)

1. Ingresar a Kibana → **Stack Management** → **Data Views**
2. Click en **Create data view**
3. Configurar:
   - **Name**: `Delivereats Logs`
   - **Index pattern**: `delivereats-*`
   - **Timestamp field**: `@timestamp`
4. Click **Save data view to Kibana**

### Dashboard recomendado: Logs por Microservicio

1. Ir a **Analytics** → **Discover**
2. Seleccionar data view `Delivereats Logs`
3. En el panel izquierdo, agregar los campos:
   - `kubernetes.labels.app` – microservicio de origen
   - `log` – mensaje del log
   - `severity` o `level` – nivel de log
4. Filtrar por servicio usando el campo `kubernetes.labels.app`

### Dashboard: Error Rate por Servicio

1. Ir a **Analytics** → **Dashboard** → **Create dashboard**
2. Agregar visualización tipo **Lens**
3. Configurar:
   - **X-axis**: `@timestamp` (intervalo: 5m)
   - **Y-axis**: Count
   - **Break down by**: `kubernetes.labels.app`
   - Filtro: `log: *error* OR log: *ERROR*`
4. Guardar como "Error Rate por Servicio"

### KQL útiles para filtrar logs

```kql
# Todos los errores del order-service
kubernetes.labels.app: "order-service" AND log: *error*

# Logs de rechazo de órdenes del CronJob
kubernetes.labels.app: "auto-reject-orders"

# Errores HTTP 5xx en el API Gateway
kubernetes.labels.app: "api-gateway" AND log: *500*

# Logs de autenticación fallida
kubernetes.labels.app: "auth-service" AND log: *unauthorized*
```

---

## 4. Prometheus – Instalación y Configuración

### Despliegue

```bash
# Namespace
kubectl apply -f k8s/monitoring/00-namespace.yaml

# ConfigMap con prometheus.yml y reglas de alertas
kubectl apply -f k8s/monitoring/01-prometheus-config.yaml

# RBAC + Deployment + Service de Prometheus
kubectl apply -f k8s/monitoring/02-prometheus.yaml

# Node Exporter DaemonSet
kubectl apply -f k8s/monitoring/03-node-exporter.yaml

# Verificar
kubectl get pods -n monitoring
# prometheus-XXXXX    1/1 Running
# node-exporter-XXXX (x N nodos)  1/1 Running
```

### Acceso a Prometheus UI

```bash
kubectl port-forward svc/prometheus -n monitoring 9090:9090

# Abrir: http://localhost:9090
```

### Verificar targets activos

1. Ir a **Status** → **Targets**
2. Deben aparecer:
   - `kubernetes-apiservers` (UP)
   - `kubernetes-nodes` (UP)
   - `node-exporter` (UP por cada nodo)
   - `delivereats-pods` (UP para pods con la anotación)
   - `rabbitmq` (UP si la anotación está en el pod de RabbitMQ)

### Agregar scraping a un microservicio

Para que Prometheus scrape un pod, agregar las siguientes anotaciones en el Deployment:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "3000"     # puerto de métricas
    prometheus.io/path: "/metrics" # path de métricas (default)
```

### Queries PromQL útiles

```promql
# CPU usage por pod
rate(container_cpu_usage_seconds_total{namespace="delivereats"}[5m])

# Memory usage por pod
container_memory_usage_bytes{namespace="delivereats"}

# HTTP request rate por servicio
rate(http_requests_total{namespace="delivereats"}[5m])

# Latencia p95 por servicio
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace="delivereats"}[5m]))

# Error rate (5xx)
rate(http_requests_total{namespace="delivereats",status=~"5.."}[5m]) /
rate(http_requests_total{namespace="delivereats"}[5m])

# Pods en CrashLoopBackOff
kube_pod_container_status_restarts_total{namespace="delivereats"} > 5

# Uso de CPU del nodo
100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memoria disponible del nodo (%)
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100
```

---

## 5. Grafana – Instalación y Dashboards

### Despliegue

```bash
# Grafana con datasources preconfigurados
kubectl apply -f k8s/monitoring/04-grafana.yaml

# Ingress para Grafana y Prometheus
kubectl apply -f k8s/monitoring/05-monitoring-ingress.yaml

# Verificar
kubectl get pods -n monitoring | grep grafana
# grafana-XXXXX  1/1 Running
```

### Acceso a Grafana

```bash
kubectl port-forward svc/grafana -n monitoring 3000:3000

# Abrir: http://localhost:3000
# Usuario: admin
# Contraseña: admin (cambiar inmediatamente en producción)
```

### Datasources preconfigurados

Grafana viene con dos datasources ya configurados:

| Nombre        | Tipo          | URL                                              |
|---------------|---------------|--------------------------------------------------|
| Prometheus    | Prometheus    | `http://prometheus.monitoring.svc.cluster.local:9090` |
| Elasticsearch | Elasticsearch | `http://elasticsearch.logging.svc.cluster.local:9200` |

Para verificar: **Configuration** → **Data sources**

### Dashboard 1: Visión General de Microservicios

1. **Dashboards** → **New** → **Import**
2. Importar por ID desde Grafana.com: `7249` (Kubernetes App Metrics)
3. Seleccionar datasource: Prometheus
4. Ajustar variable `namespace` a `delivereats`

### Dashboard 2: Métricas de Nodos

1. **Dashboards** → **New** → **Import**
2. Importar por ID: `1860` (Node Exporter Full)
3. Seleccionar datasource: Prometheus

### Dashboard 3: Logs de ELK en Grafana

1. **Dashboards** → **New** → **Add visualization**
2. Seleccionar datasource: Elasticsearch
3. Configurar query:
   - **Index**: `delivereats-*`
   - **Metric**: Count
   - **Group by**: `kubernetes.labels.app.keyword`
   - **Date histogram**: `@timestamp`, interval `5m`
4. Cambiar tipo a **Time series** o **Bar chart**
5. Guardar como "Logs por Microservicio"

### Dashboard 4: SLA Dashboard (personalizado)

Crear desde cero con los siguientes paneles:

```
Panel 1: Availability
  - Query: up{job=~"kubernetes-pods"} * 100
  - Threshold: verde>99, amarillo>95, rojo<95
  - Tipo: Stat

Panel 2: Request Rate
  - Query: sum(rate(http_requests_total{namespace="delivereats"}[5m]))
  - Tipo: Time series

Panel 3: Error Rate (%)
  - Query: sum(rate(http_requests_total{namespace="delivereats",status=~"5.."}[5m])) /
           sum(rate(http_requests_total{namespace="delivereats"}[5m])) * 100
  - Threshold: rojo>5
  - Tipo: Gauge

Panel 4: P95 Latency (ms)
  - Query: histogram_quantile(0.95,
             sum(rate(http_request_duration_seconds_bucket{namespace="delivereats"}[5m])) by (le)
           ) * 1000
  - Threshold: amarillo>500ms, rojo>2000ms
  - Tipo: Time series
```

---

## 6. Alertas

### Alertas definidas en Prometheus

Las reglas están en `k8s/monitoring/01-prometheus-config.yaml`. Para ver el estado:

```bash
# En Prometheus UI:
# Status → Rules  (ver reglas cargadas)
# Alerts          (ver alertas activas)
```

### Configurar Alertmanager (opcional)

Para recibir alertas por email o Slack, agregar un Alertmanager al namespace `monitoring`:

```yaml
# alertmanager-config.yaml (ejemplo para Slack)
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    route:
      receiver: 'slack-notifications'
    receivers:
    - name: 'slack-notifications'
      slack_configs:
      - channel: '#alerts'
        send_resolved: true
        text: '{{ range .Alerts }}*Alert:* {{ .Labels.alertname }}\n{{ end }}'
```

### Silenciar una alerta temporalmente

```bash
# Vía Prometheus UI → Alerts → click en alerta → Silence
# O via amtool si Alertmanager está instalado
amtool silence add alertname="ServiceDown" --duration=1h --comment="Mantenimiento"
```

---

## 7. Acceso a los Servicios

### Resumen de puertos y URLs

| Servicio       | Namespace  | Port-Forward                  | Ingress (si aplica)              |
|----------------|------------|-------------------------------|----------------------------------|
| Kibana         | logging    | `5601:5601`                   | `kibana.delivereats.local`       |
| Elasticsearch  | logging    | `9200:9200`                   | —                                |
| Prometheus     | monitoring | `9090:9090`                   | `prometheus.delivereats.local`   |
| Grafana        | monitoring | `3000:3000`                   | `grafana.delivereats.local`      |

### Script de port-forward rápido

```bash
#!/bin/bash
# port-forward-observability.sh
kubectl port-forward svc/kibana -n logging 5601:5601 &
kubectl port-forward svc/prometheus -n monitoring 9090:9090 &
kubectl port-forward svc/grafana -n monitoring 3000:3000 &

echo "Kibana:     http://localhost:5601"
echo "Prometheus: http://localhost:9090"
echo "Grafana:    http://localhost:3000"
wait
```

### Configurar `/etc/hosts` para Ingress local

Si se usa Ingress con hostname, agregar al `/etc/hosts` del cliente:

```bash
# Obtener IP del Ingress Controller
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "$INGRESS_IP kibana.delivereats.local" | sudo tee -a /etc/hosts
echo "$INGRESS_IP grafana.delivereats.local" | sudo tee -a /etc/hosts
echo "$INGRESS_IP prometheus.delivereats.local" | sudo tee -a /etc/hosts
```

---

## 8. Troubleshooting

### Elasticsearch no levanta (OOMKilled)

```bash
# El problema es falta de vm.max_map_count
# Verificar en cada nodo:
kubectl debug node/NODE_NAME -it --image=busybox -- sysctl vm.max_map_count

# Si es < 262144:
# Agregar initContainer en el StatefulSet o configurar kubelet con:
# --allowed-unsafe-sysctls=vm.max_map_count
```

### Fluentd no envía logs

```bash
# Ver logs de Fluentd
kubectl logs -n logging daemonset/fluentd -f

# Errores comunes:
# "Connection refused" → Elasticsearch no está listo todavía
# "Permission denied" → Problema con RBAC, verificar ClusterRole

kubectl describe clusterrole fluentd
kubectl describe clusterrolebinding fluentd
```

### Prometheus no scrape pods

```bash
# Verificar que el pod tiene las anotaciones correctas
kubectl get pod POD_NAME -o yaml | grep -A5 annotations

# Verificar ServiceAccount de Prometheus
kubectl describe clusterrole prometheus
```

### Grafana no conecta a Prometheus

```bash
# En Grafana: Configuration → Data Sources → Prometheus → Save & Test
# Si falla "dial tcp: connection refused":
kubectl exec -n monitoring deployment/grafana -- \
  curl -s http://prometheus.monitoring.svc.cluster.local:9090/-/healthy
```

### Logs de alto volumen en Elasticsearch

Si los índices crecen demasiado, configurar Index Lifecycle Management (ILM) en Kibana:

1. **Stack Management** → **Index Lifecycle Management**
2. Crear política `delivereats-logs-policy`:
   - Hot phase: rollover a los 10GB o 7 días
   - Delete phase: eliminar após 30 días
3. Asociar a los índices `delivereats-*`

---

## Referencia Rápida

```bash
# ── ELK ────────────────────────────────────────────────
kubectl get pods -n logging
kubectl logs -n logging statefulset/elasticsearch
kubectl logs -n logging deployment/kibana
kubectl logs -n logging daemonset/fluentd

# ── Monitoring ─────────────────────────────────────────
kubectl get pods -n monitoring
kubectl logs -n monitoring deployment/prometheus
kubectl logs -n monitoring deployment/grafana
kubectl logs -n monitoring daemonset/node-exporter

# ── Verificar métricas de un pod ───────────────────────
kubectl exec -n delivereats POD_NAME -- curl -s http://localhost:3000/metrics

# ── Ver alertas activas ────────────────────────────────
curl -s http://localhost:9090/api/v1/alerts | python3 -m json.tool

# ── Espacio en Elasticsearch ───────────────────────────
curl -s http://localhost:9200/_cat/indices?v&h=index,store.size
```
