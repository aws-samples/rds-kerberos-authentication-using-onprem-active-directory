
output "Aurora-postgreSQL-details" {
    
    description = "Aurora-postgreSQL-details"
    value       = var.deployAuroraPostgreSQL == "Y" ? {
        
       writer_endpoint = module.aurora_postgresql_v2[0].cluster_endpoint
       reader_endpoint = module.aurora_postgresql_v2[0].cluster_reader_endpoint
       database_name = local.database_name
} : { message = "Aurora PostgreSQL was not deployed"}
}

output "RDS-for-DB2-details" {
    
    description = "RDS-for-DB2-details"
    value       = var.deployRdsForDb2.ibm_customer_id == "do not deploy db2" ? {message = "RDS for DB2 was not deployed"} :   {
        
       db_instance_endpoint = module.rds[0].db_instance_endpoint
       database_name = local.database_name
 }
}



output "anycompany_ad" {
  description = "External/On Prem Active Directory details"
  value       = { 
    directory_id = aws_directory_service_directory.anycompany_ad.id
    access_url = aws_directory_service_directory.anycompany_ad.access_url
    dns_ips = aws_directory_service_directory.anycompany_ad.dns_ip_addresses
    admin_username = "Admin"
    arn_of_password_stored_in_aws_secrets_manager = aws_secretsmanager_secret_version.active_directory_password.arn

}
}

output "managed_ad" {
  description = "AWS Managed Active Directory details"
  value       = { 
    directory_id = aws_directory_service_directory.managed_ad.id
    access_url = aws_directory_service_directory.managed_ad.access_url
    dns_ips = aws_directory_service_directory.managed_ad.dns_ip_addresses
    admin_username = "Admin"
    arn_of_password_stored_in_aws_secrets_manager = aws_secretsmanager_secret_version.active_directory_password.arn
}
}


output "workspaces-details" {
  description = "Details required to log into the Virtual Windows desktop"
  value       = { 
    registration_code = aws_workspaces_directory.workspaces_anycompany_ad.registration_code 
    user_name = aws_workspaces_workspace.testuserdesktop.user_name
    arn_of_password_stored_in_aws_secrets_manager = aws_secretsmanager_secret_version.active_directory_password.arn
}
}

