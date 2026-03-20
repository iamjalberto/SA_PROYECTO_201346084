# ─────────────────────────────────────────────
# Cloud SQL — SQL Server 2019 (fuera del clúster GKE)
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

resource "google_sql_database_instance" "sqlserver" {
  project             = var.project_id
  name                = var.instance_name
  region              = var.region
  database_version    = "SQLSERVER_2019_STANDARD"
  deletion_protection = false

  settings {
    tier = "db-custom-2-7680"

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      require_ssl     = true
    }

    backup_configuration {
      enabled            = true
      binary_log_enabled = false
      start_time         = "03:00"
    }

    maintenance_window {
      day  = 7
      hour = 4
    }

    disk_autoresize = true
    disk_size       = 20
    disk_type       = "PD_SSD"

    availability_type = "ZONAL"
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_user" "sa_user" {
  project  = var.project_id
  name     = "sqlserver"
  instance = google_sql_database_instance.sqlserver.name
  password = var.db_password
}
