# ─────────────────────────────────────────────
# General
# ─────────────────────────────────────────────
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

# ─────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────
variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "delivereats-vpc"
}

variable "subnet_name" {
  description = "Name of the primary subnet"
  type        = string
  default     = "delivereats-subnet"
}

variable "subnet_cidr" {
  description = "CIDR block for the primary subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR for GKE Pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR for GKE Services"
  type        = string
  default     = "10.2.0.0/16"
}

# ─────────────────────────────────────────────
# GKE
# ─────────────────────────────────────────────
variable "cluster_name" {
  description = "GKE Cluster name"
  type        = string
  default     = "delivereats-gke"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "GCE machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Boot disk size for GKE nodes in GB"
  type        = number
  default     = 50
}

# ─────────────────────────────────────────────
# Database
# ─────────────────────────────────────────────
variable "db_instance_name" {
  description = "Cloud SQL instance name"
  type        = string
  default     = "delivereats-sqlserver"
}

variable "db_password" {
  description = "SQL root password (sensitive)"
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────────────
# Cloud Run (Frontend)
# ─────────────────────────────────────────────
variable "frontend_service_name" {
  description = "Cloud Run service name for the frontend"
  type        = string
  default     = "delivereats-frontend"
}

variable "frontend_image" {
  description = "Docker image for the frontend (gcr.io or artifact registry)"
  type        = string
}

variable "api_gateway_url" {
  description = "Public URL of the API Gateway exposed by GKE Ingress"
  type        = string
}

# ─────────────────────────────────────────────
# Load-Test VM
# ─────────────────────────────────────────────
variable "loadtest_vm_name" {
  description = "Name of the Compute Engine VM for load testing"
  type        = string
  default     = "delivereats-loadtest-vm"
}

variable "loadtest_machine_type" {
  description = "Machine type for the load-test VM"
  type        = string
  default     = "e2-medium"
}

variable "ssh_pub_key" {
  description = "SSH public key content to inject into the VM"
  type        = string
}
