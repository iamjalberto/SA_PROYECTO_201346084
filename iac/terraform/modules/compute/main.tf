# ─────────────────────────────────────────────
# VM dedicada para pruebas de carga (Locust)
# Configurada posteriormente por Ansible
# ─────────────────────────────────────────────
data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

resource "google_compute_instance" "loadtest" {
  project      = var.project_id
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["ssh-access", "loadtest"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 20
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.subnet_id

    access_config {
      # Ephemeral public IP para acceso SSH
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_pub_key}"
  }

  # Script de inicialización mínimo – Ansible hará la configuración idempotente
  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3 python3-pip python3-venv
  SCRIPT
}
