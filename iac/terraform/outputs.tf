output "vpc_network_name" {
  description = "VPC Network name"
  value       = module.vpc.network_name
}

output "subnet_name" {
  description = "Primary subnet name"
  value       = module.vpc.subnet_name
}

output "gke_cluster_name" {
  description = "GKE Cluster name"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE Cluster API endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "GKE Cluster CA certificate (base64)"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "db_private_ip" {
  description = "Private IP of the Cloud SQL instance"
  value       = module.database.private_ip
}

output "db_connection_name" {
  description = "Cloud SQL connection name"
  value       = module.database.connection_name
}

output "frontend_cloud_run_url" {
  description = "Public URL of the frontend Cloud Run service"
  value       = module.cloud_run.service_url
}

output "loadtest_vm_external_ip" {
  description = "External IP of the load-test VM"
  value       = module.loadtest_vm.external_ip
}
