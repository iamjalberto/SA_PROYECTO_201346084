# Delivereats - Plataforma de Delivery de Alimentos

**Proyecto Fase 3 (Final) – Software Avanzado A**  
**Universidad de San Carlos de Guatemala**  
**Facultad de Ingeniería – Escuela de Ciencias y Sistemas**

| Dato | Valor |
|------|-------|
| **Nombre** | José Alberto Alarcón Chigua |
| **Carné** | 201346084 |
| **Curso** | Software Avanzado A |
| **Catedráticos** | Everest Darwin Medinilla Rodríguez / Juan Pablo Samayoa Ruiz |
| **Tag de entrega** | `v3.0.0` |
| **Período** | 19 marzo – 23 abril 2026 |

---

## Fase 3 – DevOps, IaC y Observabilidad

La Fase 3 transforma la infraestructura manual de Fases 1 y 2 a una plataforma completamente automatizada sobre GCP, con observabilidad completa y pipelines de calidad.

### Entregables de Fase 3

| # | Entregable | Evidencia |
|---|-----------|-----------|
| 1 | Infraestructura como Código (Terraform) | [`iac/terraform/`](iac/terraform/) – 5 módulos: VPC, GKE, Cloud SQL, Cloud Run, Compute |
| 2 | Gestión de Configuración (Ansible) | [`iac/ansible/`](iac/ansible/) – role `loadtester`, playbook idempotente |
| 3 | CronJob rechazo automático + anti-spam | [`k8s/cronjob-order-reject.yaml`](k8s/cronjob-order-reject.yaml) + [`docs/cronjob-execution-logs.txt`](docs/cronjob-execution-logs.txt) |
| 4 | Stack ELK (Elasticsearch + Kibana + Fluentd) | [`k8s/elk/`](k8s/elk/) + [`docs/dashboards/kibana-delivereats-dashboard.ndjson`](docs/dashboards/kibana-delivereats-dashboard.ndjson) |
| 5 | Prometheus + Grafana + 4 alertas | [`k8s/monitoring/`](k8s/monitoring/) + [`docs/dashboards/grafana-delivereats-overview.json`](docs/dashboards/grafana-delivereats-overview.json) |
| 6 | Smoke tests automatizados | [`tests/smoke-test.sh`](tests/smoke-test.sh) |
| 7 | Pruebas de carga Locust + reporte | [`tests/locustfile.py`](tests/locustfile.py) + [`docs/locust-report.html`](docs/locust-report.html) |
| 8 | CI/CD: terraform plan + ansible-lint | [`.github/workflows/ci-cd.yaml`](.github/workflows/ci-cd.yaml) |
| 9 | Documentación Fase 3 | [`docs/DOCUMENTACION_FASE3.md`](docs/DOCUMENTACION_FASE3.md) |
| 10 | Manual de Observabilidad | [`docs/MANUAL_OBSERVABILIDAD.md`](docs/MANUAL_OBSERVABILIDAD.md) |
| 11 | SCRUM: backlog + 3 sprints + retrospectivas | [`docs/GESTION_AGIL_FASE3.md`](docs/GESTION_AGIL_FASE3.md) – [Tablero](https://github.com/users/iamjalberto/projects/3) |
| 12 | Contratos de API actualizados | [`docs/CONTRATOS_API.md`](docs/CONTRATOS_API.md) |
| 13 | Presentación técnica | [`docs/presentacion-fase3.html`](docs/presentacion-fase3.html) |

### Stack de Infraestructura Fase 3

| Herramienta | Uso |
|---|---|
| **Terraform 1.7** | Aprovisionamiento VPC, GKE, Cloud SQL, Cloud Run, VM |
| **Ansible** | Configuración idempotente de VM load-testing |
| **Kubernetes (GKE)** | Orquestación de todos los microservicios y CronJobs |
| **Elasticsearch 8.12** | Almacenamiento y búsqueda de logs centralizados |
| **Kibana 8.12** | Dashboard de logs por microservicio |
| **Fluentd** | Recolección de logs desde todos los pods |
| **Prometheus 2.51** | Métricas de nodos, pods y microservicios |
| **Grafana 10.4** | Dashboards de observabilidad + 4 alertas |
| **Locust 2.24** | Pruebas de carga (20 users, 2 min, 8.6 rps) |
| **GitHub Actions** | CI/CD: lint, test, build, push, deploy |

---

---

## 📋 Descripción del Proyecto

Delivereats es una plataforma de entrega de alimentos tipo delivery diseñada bajo una **arquitectura de microservicios**. La aplicación permite a los usuarios registrarse, iniciar sesión, explorar restaurantes, consultar menús, generar pedidos y gestionar entregas.

## 🏗️ Arquitectura

La aplicación está compuesta por **6 microservicios** independientes, cada uno con su propia base de datos:

```
┌─────────────┐     ┌──────────────────┐
│   Frontend   │────▶│   API Gateway    │ (REST - Puerto 3000)
│  (React/Vite)│     │   (Express.js)   │
│  Puerto 5173 │     └──────┬───────────┘
└─────────────┘            │ gRPC
                ┌──────────┼──────────────┐
                │          │              │
         ┌──────▼──┐ ┌────▼─────┐ ┌──────▼──────────┐
         │  Auth   │ │Restaurant│ │   Order Service  │
         │ Service │ │ Catalog  │ │   Puerto 50053   │
         │  50051  │ │  Service │ └────────┬─────────┘
         └────┬────┘ │  50052   │          │
              │      └────┬────┘    ┌──────▼──────┐
         ┌────▼──┐   ┌────▼──┐     │  Delivery   │
         │Auth DB│   │Rest DB│     │  Service    │
         │ PG    │   │ PG    │     │   50054     │
         └───────┘   └───────┘     └──────┬──────┘
                                          │
                                   ┌──────▼──┐
                                   │Deliv DB │
                                   │ PG      │
                                   └─────────┘
                          ┌──────────────────┐
                          │   Notification   │
                          │    Service       │
                          │     50055        │
                          └──────────────────┘
```

## 🛠️ Stack Tecnológico

| Componente | Tecnología |
|-----------|------------|
| **Frontend** | React 18 + Vite |
| **API Gateway** | Node.js + Express |
| **Microservicios** | Node.js + gRPC |
| **Base de Datos** | PostgreSQL 15 (independiente por servicio) |
| **Autenticación** | JWT (JSON Web Tokens) |
| **Comunicación** | REST (frontend ↔ gateway) + gRPC (gateway ↔ servicios) |
| **Contenedores** | Docker + Docker Compose |
| **Nube** | Google Cloud Platform (GCP) |
| **Email** | Nodemailer (SMTP) |

## ☁️ Despliegue en GCP

La aplicación está desplegada en **Google Cloud Platform** usando una instancia de **Compute Engine**.

| Recurso | Detalle |
|---------|---------|
| **Proyecto GCP** | `usac-sa-201346084` |
| **VM** | `delivereats-vm` |
| **Zona** | `us-central1-a` |
| **Tipo de máquina** | `e2-medium` (2 vCPU, 4 GB RAM) |
| **SO** | Ubuntu 22.04 LTS |
| **IP externa** | `34.57.204.245` |

### URLs en Producción
| Servicio | URL |
|----------|-----|
| 🌐 **Frontend** | http://34.57.204.245:5173 |
| 🔌 **API Gateway** | http://34.57.204.245:3000/api |

### Pasos del despliegue
1. Se creó un proyecto en GCP (`usac-sa-201346084`) con billing habilitado
2. Se habilitó la API de Compute Engine
3. Se creó una VM `e2-medium` con Ubuntu 22.04 y Docker preinstalado (via startup-script)
4. Se configuraron reglas de firewall para puertos 80, 3000 y 5173
5. Se copió el proyecto completo a la VM via `gcloud compute scp`
6. Se ejecutó `docker compose build && docker compose up -d` en la VM
7. Los 7 contenedores corren en la VM, cada microservicio con su BD PostgreSQL embebida

## 📦 Microservicios

### 1. API Gateway (Puerto 3000)
- Expone rutas REST al frontend
- Valida JWT en cada request
- Autorización por roles (CLIENTE, RESTAURANTE, REPARTIDOR, ADMINISTRADOR)
- Enruta peticiones a microservicios vía gRPC

### 2. Auth Service (Puerto 50051)
- Registro de usuarios (CLIENTE, RESTAURANTE, REPARTIDOR, ADMINISTRADOR)
- Login con email y contraseña
- Generación de JWT
- Validación de tokens
- Encriptación de contraseñas con bcrypt

### 3. Restaurant Catalog Service (Puerto 50052)
- CRUD de restaurantes (ADMINISTRADOR)
- CRUD de items de menú (RESTAURANTE)
- Listado de restaurantes disponibles (CLIENTE)
- Listado de menú por restaurante (CLIENTE)

### 4. Order Service (Puerto 50053)
- Creación de órdenes (CLIENTE)
- Listado de órdenes por cliente y restaurante
- Actualización de estados: CREADA → EN_PROCESO → LISTA → EN_CAMINO → ENTREGADA
- Cancelación de órdenes (CLIENTE, RESTAURANTE, REPARTIDOR)
- Rechazo de órdenes (RESTAURANTE)

### 5. Delivery Service (Puerto 50054)
- Aceptar pedidos listos (REPARTIDOR)
- Actualizar estado de entrega (EN_CAMINO, ENTREGADA, CANCELADA)
- Listado de órdenes disponibles para entrega
- Historial de entregas por repartidor

### 6. Notification Service (Puerto 50055)
- Notificación por email de orden creada
- Notificación de orden cancelada (por cliente)
- Notificación de orden en camino
- Notificación de orden cancelada (por restaurante)
- Notificación de orden cancelada (por repartidor)
- Notificación de orden rechazada

## 🗄️ Bases de Datos

Cada microservicio tiene su **propia base de datos PostgreSQL embebida** dentro de su contenedor (independiente). No existen contenedores separados de BD.

| Servicio | Base de Datos | Motor |
|----------|--------------|-------|
| Auth Service | `auth_db` | PostgreSQL 15 (embebida) |
| Restaurant Catalog | `restaurant_db` | PostgreSQL 15 (embebida) |
| Order Service | `order_db` | PostgreSQL 15 (embebida) |
| Delivery Service | `delivery_db` | PostgreSQL 15 (embebida) |

### Esquema: `auth_db`
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,        -- bcrypt hash
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL,             -- CLIENTE | RESTAURANTE | REPARTIDOR | ADMINISTRADOR
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Esquema: `restaurant_db`
```sql
CREATE TABLE restaurants (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  address VARCHAR(500),
  phone VARCHAR(50),
  schedule VARCHAR(255),
  food_type VARCHAR(100),
  owner_id INTEGER NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE menu_items (
  id SERIAL PRIMARY KEY,
  restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price DECIMAL(10, 2) NOT NULL,
  available BOOLEAN DEFAULT true,
  category VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Esquema: `order_db`
```sql
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  client_id INTEGER NOT NULL,
  client_name VARCHAR(255),
  client_email VARCHAR(255),
  restaurant_id INTEGER NOT NULL,
  restaurant_name VARCHAR(255),
  total DECIMAL(10, 2) DEFAULT 0,
  status VARCHAR(50) DEFAULT 'CREADA',   -- CREADA | EN_PROCESO | LISTA | EN_CAMINO | ENTREGADA | CANCELADA | RECHAZADA
  delivery_address TEXT,
  delivery_person_id INTEGER,
  delivery_person_name VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
  id SERIAL PRIMARY KEY,
  order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
  menu_item_id INTEGER,
  name VARCHAR(255),
  quantity INTEGER DEFAULT 1,
  price DECIMAL(10, 2)
);
```

### Esquema: `delivery_db`
```sql
CREATE TABLE deliveries (
  id SERIAL PRIMARY KEY,
  order_id INTEGER UNIQUE NOT NULL,
  delivery_person_id INTEGER NOT NULL,
  delivery_person_name VARCHAR(255),
  status VARCHAR(50) DEFAULT 'EN_CAMINO',  -- EN_CAMINO | ENTREGADA | CANCELADA
  accepted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  delivered_at TIMESTAMP
);
```

## 📡 Comunicación gRPC (Protobuf)

Cada microservicio tiene sus propios archivos `.proto` dentro de su directorio `src/proto/`.

### `auth.proto` — AuthService
| RPC | Request | Response | Descripción |
|-----|---------|----------|-------------|
| `Register` | email, password, role, name | success, message, user_id | Registro de usuario |
| `Login` | email, password | success, token, message | Inicio de sesión + JWT |
| `ValidateToken` | token | valid, user_id, email, role, name | Validar JWT |

### `restaurant.proto` — RestaurantCatalogService
| RPC | Request | Response | Descripción |
|-----|---------|----------|-------------|
| `CreateRestaurant` | name, address, phone, ... | restaurant | Crear restaurante |
| `GetRestaurant` | id | restaurant | Obtener restaurante |
| `ListRestaurants` | — | restaurants[] | Listar todos |
| `UpdateRestaurant` | id, name, address, ... | restaurant | Actualizar |
| `DeleteRestaurant` | id | success, message | Eliminar |
| `CreateMenuItem` | restaurant_id, name, price, ... | item | Crear producto |
| `ListMenuItems` | restaurant_id | items[] | Listar menú |
| `UpdateMenuItem` | id, name, price, ... | item | Actualizar producto |
| `DeleteMenuItem` | id | success, message | Eliminar producto |

### `order.proto` — OrderService
| RPC | Request | Response | Descripción |
|-----|---------|----------|-------------|
| `CreateOrder` | client_id, restaurant_id, items[], ... | order | Crear orden |
| `GetOrder` | id | order | Detalle de orden |
| `ListOrdersByClient` | client_id | orders[] | Órdenes del cliente |
| `ListOrdersByRestaurant` | restaurant_id | orders[] | Órdenes del restaurante |
| `ListReadyOrders` | — | orders[] | Órdenes listas para entrega |
| `UpdateOrderStatus` | id, status, ... | order | Actualizar estado |
| `CancelOrder` | id, reason | order | Cancelar orden |

### `delivery.proto` — DeliveryService
| RPC | Request | Response | Descripción |
|-----|---------|----------|-------------|
| `AcceptOrder` | order_id, delivery_person_id, ... | delivery | Aceptar pedido |
| `UpdateDeliveryStatus` | order_id, status, reason | delivery | Actualizar entrega |
| `GetDeliveryByOrder` | order_id | delivery | Consultar entrega |
| `ListAvailableOrders` | — | orders[] | Órdenes disponibles |
| `ListMyDeliveries` | delivery_person_id | deliveries[] | Mis entregas |

### `notification.proto` — NotificationService
| RPC | Request | Response | Descripción |
|-----|---------|----------|-------------|
| `NotifyOrderCreated` | order info | success | Correo: orden creada |
| `NotifyCancelledByClient` | order info | success | Correo: cancelada por cliente |
| `NotifyOrderInRoute` | order + delivery info | success | Correo: en camino |
| `NotifyCancelledByRestaurant` | order + reason | success | Correo: cancelada por restaurante |
| `NotifyCancelledByDelivery` | order + reason | success | Correo: cancelada por repartidor |
| `NotifyOrderRejected` | order + reason | success | Correo: orden rechazada |

## 🔐 Autenticación y Autorización

- **JWT** generado en el Auth Service al hacer login
- El **API Gateway** valida el token en cada request protegido
- Autorización basada en **roles**: CLIENTE, RESTAURANTE, REPARTIDOR, ADMINISTRADOR
- Contraseñas almacenadas con **bcrypt** (hash + salt)
- Token incluye: `id`, `email`, `role`, `name`, `iat`, `exp` (24h)

## 🔧 Decisiones Técnicas

1. **PostgreSQL embebido**: Cada microservicio incluye PostgreSQL dentro de su contenedor Docker. Esto garantiza total independencia de BD sin contenedores adicionales.

2. **gRPC para comunicación interna**: Se eligió gRPC sobre REST para la comunicación entre microservicios por su eficiencia, contratos estrictos (protobuf) y tipado fuerte.

3. **REST para el frontend**: El API Gateway expone endpoints REST que el frontend consume con Axios. Esto simplifica la integración con React.

4. **Node.js para todos los servicios**: Se usó un stack homogéneo (Node.js + Express) para reducir la complejidad operativa y facilitar el mantenimiento.

5. **Docker multi-stage para frontend**: El frontend se construye con Vite y se sirve con Nginx, resultando en una imagen ligera de ~25MB.

6. **GCP Compute Engine**: Se eligió una VM sobre Cloud Run o GKE por simplicidad de despliegue con Docker Compose, manteniendo la misma configuración local y en producción.

## 🚀 Cómo Ejecutar

### Requisitos
- Docker y Docker Compose instalados
- Git

### Ejecución Local con Docker Compose

```bash
# Clonar el repositorio
git clone https://github.com/iamjalberto/SA_PROYECTO_201346084.git
cd SA_PROYECTO_201346084

# Levantar todos los servicios
docker-compose up --build

# O en segundo plano
docker-compose up --build -d
```

### Acceso
- **Frontend:** http://localhost:5173
- **API Gateway:** http://localhost:3000/api/health

### Variables de Entorno para Email (Opcional)
```bash
export SMTP_USER=tu_email@gmail.com
export SMTP_PASS=tu_app_password
docker-compose up --build
```

## 📡 API Endpoints

### Auth
| Método | Ruta | Descripción | Roles |
|--------|------|-------------|-------|
| POST | `/api/auth/register` | Registro de usuario | Público |
| POST | `/api/auth/login` | Inicio de sesión | Público |

### Restaurantes
| Método | Ruta | Descripción | Roles |
|--------|------|-------------|-------|
| GET | `/api/restaurants` | Listar restaurantes | Autenticado |
| GET | `/api/restaurants/:id` | Detalle de restaurante | Autenticado |
| POST | `/api/restaurants` | Crear restaurante | ADMINISTRADOR |
| PUT | `/api/restaurants/:id` | Actualizar restaurante | ADMINISTRADOR |
| DELETE | `/api/restaurants/:id` | Eliminar restaurante | ADMINISTRADOR |
| GET | `/api/restaurants/:id/menu` | Ver menú | Autenticado |
| POST | `/api/restaurants/:id/menu` | Crear producto | RESTAURANTE |
| PUT | `/api/restaurants/menu/:itemId` | Actualizar producto | RESTAURANTE |
| DELETE | `/api/restaurants/menu/:itemId` | Eliminar producto | RESTAURANTE |

### Órdenes
| Método | Ruta | Descripción | Roles |
|--------|------|-------------|-------|
| POST | `/api/orders` | Crear orden | CLIENTE |
| GET | `/api/orders/my` | Mis órdenes | CLIENTE |
| GET | `/api/orders/restaurant/:id` | Órdenes del restaurante | RESTAURANTE |
| GET | `/api/orders/ready` | Órdenes listas | REPARTIDOR |
| GET | `/api/orders/:id` | Detalle de orden | Autenticado |
| PUT | `/api/orders/:id/status` | Actualizar estado | RESTAURANTE |
| PUT | `/api/orders/:id/cancel` | Cancelar orden | CLIENTE, RESTAURANTE, REPARTIDOR |
| PUT | `/api/orders/:id/reject` | Rechazar orden | RESTAURANTE |

### Delivery
| Método | Ruta | Descripción | Roles |
|--------|------|-------------|-------|
| POST | `/api/delivery/accept` | Aceptar pedido | REPARTIDOR |
| PUT | `/api/delivery/status` | Actualizar estado entrega | REPARTIDOR |
| GET | `/api/delivery/available` | Órdenes disponibles | REPARTIDOR |
| GET | `/api/delivery/my` | Mis entregas | REPARTIDOR |

## 🐳 Docker

Cada servicio tiene su propio Dockerfile optimizado con imágenes `node:18-alpine`. El frontend usa un build multi-stage con nginx para servir la aplicación estática.

## 📁 Estructura del Proyecto

```
SA_PROYECTO_201346084/
├── docker-compose.yml
├── .gitignore
├── README.md
├── proto/                          # Protos originales (referencia)
│   ├── auth.proto
│   ├── restaurant.proto
│   ├── order.proto
│   ├── delivery.proto
│   └── notification.proto
├── api-gateway/                    # API Gateway (REST → gRPC)
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       ├── index.js
│       ├── grpcClients.js
│       ├── middleware.js
│       ├── proto/                  # Copias locales de .proto
│       └── routes/
│           ├── auth.js
│           ├── restaurants.js
│           ├── orders.js
│           └── delivery.js
├── auth-service/                   # Servicio de autenticación + BD embebida
│   ├── Dockerfile
│   ├── entrypoint.sh              # Inicia PostgreSQL + Node.js
│   ├── package.json
│   └── src/
│       ├── index.js
│       ├── db.js
│       └── proto/auth.proto
├── restaurant-catalog-service/     # Catálogo + BD embebida
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── package.json
│   └── src/
│       ├── index.js
│       ├── db.js
│       └── proto/restaurant.proto
├── order-service/                  # Órdenes + BD embebida
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── package.json
│   └── src/
│       ├── index.js
│       ├── db.js
│       └── proto/order.proto
├── delivery-service/               # Entregas + BD embebida
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── package.json
│   └── src/
│       ├── index.js
│       ├── db.js
│       └── proto/
│           ├── delivery.proto
│           └── order.proto         # Cliente gRPC a order-service
├── notification-service/           # Notificaciones (sin BD)
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       ├── index.js
│       └── proto/notification.proto
└── frontend/                       # React 18 + Vite + Nginx
    ├── Dockerfile
    ├── nginx.conf
    ├── package.json
    └── src/
        ├── App.jsx
        ├── main.jsx
        ├── index.css
        ├── utils/validators.js     # Validaciones de formulario
        ├── components/FieldError.jsx
        ├── services/api.js
        └── pages/
            ├── Login.jsx
            ├── Register.jsx
            ├── ClientDashboard.jsx
            ├── RestaurantDashboard.jsx
            ├── DeliveryDashboard.jsx
            ├── AdminDashboard.jsx
            ├── RestaurantMenu.jsx
            ├── CreateOrder.jsx
            └── MyOrders.jsx
```
