terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "delivereats-tfstate-usac-201346084"
    prefix = "terraform/production"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ─────────────────────────────────────────────
# VPC, Subredes y Firewall
# ─────────────────────────────────────────────
module "vpc" {
  source        = "./modules/vpc"
  project_id    = var.project_id
  region        = var.region
  network_name  = var.network_name
  subnet_name   = var.subnet_name
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
}

# ─────────────────────────────────────────────
# GKE Cluster + Node Pool
# ─────────────────────────────────────────────
module "gke" {
  source              = "./modules/gke"
  project_id          = var.project_id
  region              = var.region
  zone                = var.zone
  cluster_name        = var.cluster_name
  network_id          = module.vpc.network_id
  subnet_id           = module.vpc.subnet_id
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name
  node_count          = var.node_count
  machine_type        = var.machine_type
  disk_size_gb        = var.disk_size_gb

  depends_on = [module.vpc]
}

# ─────────────────────────────────────────────
# Base de Datos: Cloud SQL (SQL Server) fuera de GKE
# ─────────────────────────────────────────────
module "database" {
  source        = "./modules/database"
  project_id    = var.project_id
  region        = var.region
  instance_name = var.db_instance_name
  db_password   = var.db_password
  network_id    = module.vpc.network_id

  depends_on = [module.vpc]
}

# ─────────────────────────────────────────────
# Cloud Run: Frontend Serverless
# ─────────────────────────────────────────────
module "cloud_run" {
  source          = "./modules/cloud_run"
  project_id      = var.project_id
  region          = var.region
  service_name    = var.frontend_service_name
  image           = var.frontend_image
  api_gateway_url = var.api_gateway_url

  depends_on = [module.gke]
}

# ─────────────────────────────────────────────
# VM de Load-Testing (aprovisionada por Ansible)
# ─────────────────────────────────────────────
module "loadtest_vm" {
  source       = "./modules/compute"
  project_id   = var.project_id
  zone         = var.zone
  vm_name      = var.loadtest_vm_name
  machine_type = var.loadtest_machine_type
  network_id   = module.vpc.network_id
  subnet_id    = module.vpc.subnet_id
  ssh_pub_key  = var.ssh_pub_key

  depends_on = [module.vpc]
}
