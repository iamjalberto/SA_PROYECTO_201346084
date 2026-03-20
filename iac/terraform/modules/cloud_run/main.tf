# ─────────────────────────────────────────────
# Cloud Run — Frontend Serverless
# ─────────────────────────────────────────────
resource "google_cloud_run_v2_service" "frontend" {
  project  = var.project_id
  name     = var.service_name
  location = var.region

  template {
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    containers {
      image = var.image

      ports {
        container_port = 80
      }

      env {
        name  = "VITE_API_BASE_URL"
        value = var.api_gateway_url
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }
}

# Permitir tráfico público sin autenticación
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
