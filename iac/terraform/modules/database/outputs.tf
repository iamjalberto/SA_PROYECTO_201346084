output "private_ip"      { value = google_sql_database_instance.sqlserver.private_ip_address }
output "connection_name" { value = google_sql_database_instance.sqlserver.connection_name }
output "instance_name"   { value = google_sql_database_instance.sqlserver.name }
