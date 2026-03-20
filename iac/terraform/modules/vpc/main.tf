# ─────────────────────────────────────────────
# VPC Network
# ─────────────────────────────────────────────
resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# ─────────────────────────────────────────────
# Subred principal con rangos secundarios para GKE
# ─────────────────────────────────────────────
resource "google_compute_subnetwork" "main" {
  project       = var.project_id
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.services_cidr
  }
}

# ─────────────────────────────────────────────
# Firewall – reglas mínimas
# ─────────────────────────────────────────────

# Permite tráfico interno dentro de la VPC
resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]
  description   = "Allow all internal VPC traffic"
}

# Permite SSH desde IPs corporativas (ajustar source_ranges según necesidad)
resource "google_compute_firewall" "allow_ssh" {
  project = var.project_id
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-access"]
  description   = "Allow SSH - restrict source_ranges in production"
}

# Permite HTTP/HTTPS para el Ingress de GKE
resource "google_compute_firewall" "allow_http_https" {
  project = var.project_id
  name    = "${var.network_name}-allow-http-https"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-node"]
  description   = "Allow HTTP/HTTPS ingress"
}

# Health-checks de GCP
resource "google_compute_firewall" "allow_health_checks" {
  project = var.project_id
  name    = "${var.network_name}-allow-health-checks"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["gke-node"]
  description   = "Allow GCP health checks"
}
