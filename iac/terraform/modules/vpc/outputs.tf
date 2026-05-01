output "network_id" { value = google_compute_network.vpc.id }
output "network_name" { value = google_compute_network.vpc.name }
output "subnet_id" { value = google_compute_subnetwork.main.id }
output "subnet_name" { value = google_compute_subnetwork.main.name }
output "pods_range_name" { value = "gke-pods" }
output "services_range_name" { value = "gke-services" }
