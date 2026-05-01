# ─────────────────────────────────────────────
# Cloud SQL — PostgreSQL 14 (fuera del clúster GKE)
# ─────────────────────────────────────────────

# Private Service Connection (necesaria para IPs privadas de Cloud SQL)
resource "google_compute_global_address" "private_ip_range" {
  project       = var.project_id
  name          = "${var.instance_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = var.network_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

resource "google_sql_database_instance" "postgres" {
  project             = var.project_id
  name                = var.instance_name
  region              = var.region
  database_version    = "POSTGRES_14"
  deletion_protection = false

  settings {
    tier = "db-g1-small"

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      require_ssl     = false
    }

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }

    maintenance_window {
      day  = 7
      hour = 4
    }

    disk_autoresize = true
    disk_size       = 10
    disk_type       = "PD_SSD"

    availability_type = "ZONAL"
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "delivereats" {
  project  = var.project_id
  name     = "delivereats"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_database" "auth_db" {
  project  = var.project_id
  name     = "auth_db"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_database" "restaurant_db" {
  project  = var.project_id
  name     = "restaurant_db"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_database" "order_db" {
  project  = var.project_id
  name     = "order_db"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_database" "delivery_db" {
  project  = var.project_id
  name     = "delivery_db"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_database" "payment_db" {
  project  = var.project_id
  name     = "payment_db"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "postgres" {
  project  = var.project_id
  name     = "postgres"
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}
