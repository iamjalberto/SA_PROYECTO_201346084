"""
locustfile.py – Pruebas de carga para Delivereats
Simula flujos reales de usuario: registro, login, explorar restaurantes,
crear orden, consultar pagos.

Uso básico:
    locust -f locustfile.py --host http://YOUR_API_GATEWAY_URL

Headless (2 min, 20 usuarios):
    locust -f locustfile.py --host http://URL \
        --headless --users 20 --spawn-rate 5 \
        --run-time 2m --csv reports/locust --html reports/report.html
"""

import random
import string
from locust import HttpUser, TaskSet, task, between, events
from faker import Faker

fake = Faker("es_GT")


# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────

def random_email() -> str:
    suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
    return f"loadtest_{suffix}@delivereats.test"


def random_password() -> str:
    return "Test1234!"


# ─────────────────────────────────────────────────────────────────────
# Task Sets
# ─────────────────────────────────────────────────────────────────────

class BrowseTaskSet(TaskSet):
    """Tareas de exploración sin autenticación."""

    @task(3)
    def list_restaurants(self):
        with self.client.get("/api/restaurants", catch_response=True) as resp:
            if resp.status_code in (200, 404):
                resp.success()

    @task(1)
    def health_check(self):
        with self.client.get("/health", catch_response=True) as resp:
            if resp.status_code in (200, 204):
                resp.success()


class AuthenticatedTaskSet(TaskSet):
    """Tareas que requieren JWT. Se autentica al inicio."""

    token: str = ""
    user_email: str = ""

    def on_start(self):
        """Registrar y luego iniciar sesión."""
        self.user_email = random_email()
        password = random_password()

        # Registro
        self.client.post(
            "/api/auth/register",
            json={
                "name": fake.name(),
                "email": self.user_email,
                "password": password,
                "role": "CLIENTE",
            },
        )

        # Login
        resp = self.client.post(
            "/api/auth/login",
            json={"email": self.user_email, "password": password},
        )
        if resp.status_code == 200:
            data = resp.json()
            self.token = data.get("token", data.get("access_token", ""))

    def _headers(self) -> dict:
        return {"Authorization": f"Bearer {self.token}"}

    @task(4)
    def list_restaurants(self):
        with self.client.get(
            "/api/restaurants",
            headers=self._headers(),
            catch_response=True,
        ) as resp:
            if resp.status_code in (200, 404):
                resp.success()

    @task(2)
    def get_fx_rates(self):
        for currency in ["USD", "MXN", "EUR"]:
            with self.client.get(
                f"/api/fx/convert?from=GTQ&to={currency}&amount=100",
                headers=self._headers(),
                catch_response=True,
            ) as resp:
                if resp.status_code in (200, 404):
                    resp.success()

    @task(2)
    def list_my_orders(self):
        with self.client.get(
            "/api/orders/my",
            headers=self._headers(),
            catch_response=True,
        ) as resp:
            if resp.status_code in (200, 401, 404):
                resp.success()

    @task(1)
    def get_wallet(self):
        with self.client.get(
            "/api/payments/wallet",
            headers=self._headers(),
            catch_response=True,
        ) as resp:
            if resp.status_code in (200, 401, 404):
                resp.success()

    @task(1)
    def create_order(self):
        """Intenta crear una orden – puede fallar sin datos reales."""
        with self.client.post(
            "/api/orders",
            headers=self._headers(),
            json={
                "restaurantId": 1,
                "items": [{"productId": 1, "quantity": 2}],
                "deliveryAddress": fake.address(),
                "paymentMethod": "WALLET",
            },
            catch_response=True,
        ) as resp:
            if resp.status_code in (200, 201, 400, 404, 422):
                resp.success()


# ─────────────────────────────────────────────────────────────────────
# User classes
# ─────────────────────────────────────────────────────────────────────

class GuestUser(HttpUser):
    """Usuario anónimo – navegación pública."""
    tasks = [BrowseTaskSet]
    wait_time = between(1, 3)
    weight = 30


class RegisteredUser(HttpUser):
    """Usuario autenticado – flujo completo."""
    tasks = [AuthenticatedTaskSet]
    wait_time = between(2, 5)
    weight = 70


# ─────────────────────────────────────────────────────────────────────
# Event hooks para logging mejorado
# ─────────────────────────────────────────────────────────────────────

@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, **kwargs):
    if exception:
        print(f"[LOCUST-ERROR] {request_type} {name} | {exception}")
