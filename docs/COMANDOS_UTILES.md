# Comandos Útiles — Delivereats Fase 3

Referencia rápida de comandos para operar, depurar y monitorear la infraestructura de Delivereats en GCP.

---

## Índice

1. [Kubernetes – Pods y Deployments](#1-kubernetes--pods-y-deployments)
2. [Kubernetes – Logs](#2-kubernetes--logs)
3. [Kubernetes – Servicios e Ingress](#3-kubernetes--servicios-e-ingress)
4. [Kubernetes – CronJobs](#4-kubernetes--cronjobs)
5. [GCP – VMs (Compute Engine)](#5-gcp--vms-compute-engine)
6. [GCP – Cloud SQL](#6-gcp--cloud-sql)
7. [GCP – Cloud Run](#7-gcp--cloud-run)
8. [GCP – Artifact Registry](#8-gcp--artifact-registry)
9. [Terraform](#9-terraform)
10. [Ansible](#10-ansible)
11. [Observabilidad – ELK](#11-observabilidad--elk)
12. [Observabilidad – Prometheus y Grafana](#12-observabilidad--prometheus-y-grafana)
13. [Pruebas](#13-pruebas)
14. [CI/CD](#14-cicd)

---

## 1. Kubernetes – Pods y Deployments

```bash
# Ver todos los pods del proyecto (namespace delivereats)
kubectl get pods -n delivereats

# Ver pods con IP y nodo asignado
kubectl get pods -n delivereats -o wide

# Ver todos los pods en todos los namespaces
kubectl get pods -A

# Ver estado detallado de un pod específico
kubectl describe pod <nombre-pod> -n delivereats

# Ver deployments
kubectl get deployments -n delivereats

# Ver estado de un rollout
kubectl rollout status deployment/<nombre-svc> -n delivereats

# Escalar un deployment
kubectl scale deployment <nombre-svc> --replicas=2 -n delivereats

# Reiniciar un deployment (rolling restart)
kubectl rollout restart deployment/<nombre-svc> -n delivereats

# Ver consumo de recursos (CPU/RAM) por pod
kubectl top pods -n delivereats

# Ver consumo de recursos por nodo
kubectl top nodes
```

---

## 2. Kubernetes – Logs

```bash
# Ver logs de un servicio (últimas 100 líneas)
kubectl logs -n delivereats deployment/api-gateway --tail=100

# Seguir logs en tiempo real
kubectl logs -n delivereats deployment/auth-service -f

# Ver logs de un pod específico
kubectl logs -n delivereats <nombre-pod>

# Ver logs de un contenedor específico (multi-container pods)
kubectl logs -n delivereats <nombre-pod> -c <nombre-contenedor>

# Ver logs de pods previos (crash anterior)
kubectl logs -n delivereats <nombre-pod> --previous

# Ver logs de todos los pods de un servicio
kubectl logs -n delivereats -l app=order-service --tail=50

# Logs del namespace de logging (ELK)
kubectl logs -n logging deployment/kibana --tail=50
kubectl logs -n logging -l app=fluentd --tail=30

# Logs del namespace de monitoring
kubectl logs -n monitoring deployment/prometheus --tail=50
kubectl logs -n monitoring deployment/grafana --tail=30
```

---

## 3. Kubernetes – Servicios e Ingress

```bash
# Ver todos los servicios
kubectl get svc -n delivereats

# Ver ingress y su IP externa
kubectl get ingress -n delivereats
kubectl get ingress -n logging
kubectl get ingress -n monitoring

# Ver IP del Ingress NGINX (LoadBalancer)
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Descripción detallada del ingress
kubectl describe ingress delivereats-ingress -n delivereats

# Ver endpoints (IPs reales de los pods detrás de un svc)
kubectl get endpoints -n delivereats

# Ver PersistentVolumeClaims
kubectl get pvc -n delivereats

# Ver ConfigMaps
kubectl get configmap -n delivereats

# Ver Secrets (nombres, no valores)
kubectl get secrets -n delivereats
```

---

## 4. Kubernetes – CronJobs

```bash
# Ver CronJobs
kubectl get cronjobs -n delivereats

# Ver jobs generados por el CronJob
kubectl get jobs -n delivereats

# Ver logs del último job ejecutado
kubectl logs -n delivereats -l job-name=$(kubectl get jobs -n delivereats --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

# Ejecutar el CronJob manualmente (crear job ad-hoc)
kubectl create job --from=cronjob/order-auto-reject manual-reject-$(date +%s) -n delivereats

# Describir el CronJob
kubectl describe cronjob order-auto-reject -n delivereats

# Ver historial de jobs (últimos 5)
kubectl get jobs -n delivereats --sort-by=.metadata.creationTimestamp | tail -5
```

---

## 5. GCP – VMs (Compute Engine)

```bash
# Listar todas las VMs del proyecto
gcloud compute instances list --project=usac-sa-201346084

# Ver detalles de la VM de load-test
gcloud compute instances describe delivereats-loadtest-vm \
  --zone=us-central1-a \
  --project=usac-sa-201346084

# SSH a la VM de load-test
gcloud compute ssh delivereats-loadtest-vm \
  --zone=us-central1-a \
  --project=usac-sa-201346084

# SSH con llave privada directamente
ssh -i ~/.ssh/delivereats-loadtest ubuntu@34.9.134.8

# Ver logs de startup de la VM
gcloud compute instances get-serial-port-output delivereats-loadtest-vm \
  --zone=us-central1-a \
  --project=usac-sa-201346084

# Iniciar/detener VM para ahorrar costos
gcloud compute instances stop delivereats-loadtest-vm --zone=us-central1-a
gcloud compute instances start delivereats-loadtest-vm --zone=us-central1-a

# Ver nodos del cluster GKE
gcloud compute instances list \
  --filter="name~'gke-delivereats'" \
  --project=usac-sa-201346084
```

---

## 6. GCP – Cloud SQL

```bash
# Listar instancias de Cloud SQL
gcloud sql instances list --project=usac-sa-201346084

# Ver detalles de la instancia (IP privada, tier, etc.)
gcloud sql instances describe delivereats-db --project=usac-sa-201346084

# Listar bases de datos
gcloud sql databases list --instance=delivereats-db --project=usac-sa-201346084

# Conectar a la DB desde la VM (via Cloud SQL Auth Proxy o psql directo)
# Nota: desde dentro del cluster usar IP privada: 10.198.112.3
psql -h 10.198.112.3 -U postgres -d auth_db

# Ver logs de Cloud SQL
gcloud sql operations list --instance=delivereats-db \
  --project=usac-sa-201346084 --limit=10

# Ver uso de almacenamiento
gcloud sql instances describe delivereats-db \
  --project=usac-sa-201346084 \
  --format="value(settings.dataDiskSizeGb)"
```

---

## 7. GCP – Cloud Run

```bash
# Listar servicios de Cloud Run
gcloud run services list --project=usac-sa-201346084 --region=us-central1

# Ver detalles y URL del servicio frontend
gcloud run services describe delivereats-frontend \
  --project=usac-sa-201346084 \
  --region=us-central1

# Ver logs del servicio Cloud Run
gcloud run services logs read delivereats-frontend \
  --project=usac-sa-201346084 \
  --region=us-central1 \
  --limit=50

# Ver revisiones (historial de deploys)
gcloud run revisions list \
  --service=delivereats-frontend \
  --project=usac-sa-201346084 \
  --region=us-central1

# URL pública del frontend
# https://delivereats-frontend-cmszttthta-uc.a.run.app
```

---

## 8. GCP – Artifact Registry

```bash
# Listar repositorios
gcloud artifacts repositories list \
  --project=usac-sa-201346084 \
  --location=us-central1

# Listar imágenes en el repositorio
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/usac-sa-201346084/delivereats \
  --project=usac-sa-201346084

# Ver tags de una imagen específica
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/usac-sa-201346084/delivereats/api-gateway \
  --include-tags \
  --project=usac-sa-201346084

# Autenticar Docker con Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Pull de una imagen
docker pull us-central1-docker.pkg.dev/usac-sa-201346084/delivereats/api-gateway:latest
```

---

## 9. Terraform

```bash
# Desde el directorio iac/terraform
cd iac/terraform

# Ver estado actual (recursos gestionados)
terraform show

# Ver resumen del estado
terraform state list

# Verificar que no hay cambios pendientes
terraform plan

# Ver outputs (IPs, URLs, etc.)
terraform output
terraform output -raw ingress_ip
terraform output -raw cloud_run_url
terraform output -raw loadtest_vm_ip
terraform output -raw db_private_ip

# Aplicar cambios (con confirmación)
terraform apply

# Aplicar solo un módulo específico
terraform apply -target=module.gke
terraform apply -target=module.database
terraform apply -target=module.cloud_run

# Ver el estado de un recurso específico
terraform state show module.gke.google_container_cluster.primary

# Formatear archivos .tf
terraform fmt -recursive

# Validar la configuración
terraform validate
```

---

## 10. Ansible

```bash
# Desde el directorio iac/ansible
cd iac/ansible

# Ver inventario
cat inventory/hosts.ini

# Test de conectividad (ping)
ansible all -i inventory/hosts.ini -m ping

# Ejecutar el playbook completo
ansible-playbook -i inventory/hosts.ini playbooks/setup-loadtest.yml

# Ejecutar solo una tarea específica (por tag)
ansible-playbook -i inventory/hosts.ini playbooks/setup-loadtest.yml --tags install

# Dry-run (check mode, no aplica cambios)
ansible-playbook -i inventory/hosts.ini playbooks/setup-loadtest.yml --check

# Ver facts de los hosts
ansible all -i inventory/hosts.ini -m setup | head -80

# Linter
ansible-lint playbooks/setup-loadtest.yml
```

---

## 11. Observabilidad – ELK

```bash
# Acceder a Kibana (via port-forward local)
kubectl port-forward -n logging svc/kibana 5601:5601
# Luego abrir: http://localhost:5601

# Ver URL del ingress de Kibana
kubectl get ingress -n logging

# Ver estado de Elasticsearch
kubectl exec -n logging elasticsearch-0 -- \
  curl -s http://localhost:9200/_cluster/health | python3 -m json.tool

# Ver índices de Elasticsearch
kubectl exec -n logging elasticsearch-0 -- \
  curl -s http://localhost:9200/_cat/indices?v

# Ver indices de Delivereats
kubectl exec -n logging elasticsearch-0 -- \
  curl -s "http://localhost:9200/_cat/indices/delivereats-*?v"

# Ver logs de un servicio desde Elasticsearch
kubectl exec -n logging elasticsearch-0 -- curl -s \
  "http://localhost:9200/delivereats-api-gateway-*/_search?q=level:error&size=5" \
  | python3 -m json.tool

# Reiniciar Fluentd si deja de enviar logs
kubectl rollout restart daemonset/fluentd -n logging
```

---

## 12. Observabilidad – Prometheus y Grafana

```bash
# Acceder a Prometheus (via port-forward)
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Luego abrir: http://localhost:9090

# Acceder a Grafana (via port-forward)
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Luego abrir: http://localhost:3000
# Usuario: admin / Contraseña: admin (cambiar en primer login)

# Ver targets activos de Prometheus
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- http://localhost:9090/api/v1/targets | python3 -m json.tool | head -50

# Consultar una métrica específica (ejemplo: CPU)
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=node_cpu_seconds_total' \
  | python3 -m json.tool | head -30

# Ver reglas de alertas activas
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- http://localhost:9090/api/v1/rules | python3 -m json.tool

# Ver alertas disparadas
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- http://localhost:9090/api/v1/alerts | python3 -m json.tool

# Reiniciar stack de monitoreo
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout restart deployment/grafana -n monitoring
```

---

## 13. Pruebas

```bash
# Smoke tests contra el cluster (desde local)
BASE_URL="http://34.132.92.230" bash tests/smoke-test.sh

# Smoke tests contra Cloud Run
BASE_URL="https://delivereats-frontend-cmszttthta-uc.a.run.app" bash tests/smoke-test.sh

# Pruebas de carga con Locust (desde la VM)
ssh ubuntu@34.9.134.8 \
  "/opt/delivereats-loadtest/run-locust.sh"

# Locust headless manual desde la VM
ssh ubuntu@34.9.134.8 \
  "source /opt/delivereats-loadtest/venv/bin/activate && \
   locust -f /opt/delivereats-loadtest/locustfile.py \
     --host http://34.132.92.230 \
     --headless \
     --users 20 \
     --spawn-rate 5 \
     --run-time 2m \
     --html /tmp/locust-report.html"

# Copiar reporte de Locust a local
scp ubuntu@34.9.134.8:/tmp/locust-report.html docs/locust-report.html

# Test rápido de un endpoint
curl -s http://34.132.92.230/api/health | python3 -m json.tool

# Test de autenticación
TOKEN=$(curl -s -X POST http://34.132.92.230/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test1234!"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
echo "Token: $TOKEN"

# Test de endpoint protegido
curl -s http://34.132.92.230/api/restaurants \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

---

## 14. CI/CD

```bash
# Ver los últimos runs del pipeline
gh run list --repo iamjalberto/SA_PROYECTO_201346084 --limit 5

# Ver detalle de un run específico
gh run view <RUN_ID> --repo iamjalberto/SA_PROYECTO_201346084

# Ver logs de un run fallido
gh run view <RUN_ID> --repo iamjalberto/SA_PROYECTO_201346084 --log-failed

# Relanzar un run fallido
gh run rerun <RUN_ID> --repo iamjalberto/SA_PROYECTO_201346084

# Ver el último run y sus jobs
gh run list --repo iamjalberto/SA_PROYECTO_201346084 --limit 1 \
  --json databaseId,conclusion,status,displayTitle -q '.[0]'

# Ver secrets configurados en el repo (solo nombres)
gh secret list --repo iamjalberto/SA_PROYECTO_201346084

# Forzar un nuevo pipeline (commit vacío)
git commit --allow-empty -m "chore: trigger CI/CD" && git push origin main
```

---

## Referencias Rápidas

| Recurso | Valor |
|---------|-------|
| **Ingress IP (API + Frontend GKE)** | `34.132.92.230` |
| **Cloud Run URL** | `https://delivereats-frontend-cmszttthta-uc.a.run.app` |
| **Cloud SQL IP privada** | `10.198.112.3` |
| **VM Load-test IP** | `34.9.134.8` |
| **GKE Cluster** | `delivereats-gke` / `us-central1-a` |
| **Artifact Registry** | `us-central1-docker.pkg.dev/usac-sa-201346084/delivereats` |
| **GCP Proyecto** | `usac-sa-201346084` |
| **GitHub Repo** | `iamjalberto/SA_PROYECTO_201346084` |
