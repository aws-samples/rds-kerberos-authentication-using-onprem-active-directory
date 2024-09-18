

################################################################################
# Create Secrets for Active Directory Admin Password
################################################################################

resource "random_password" "active_directory_password" {
length = 12
special = false
override_special = "_%@"
}

resource "aws_secretsmanager_secret" "active_directory_password" {
  name = "active_directory_password"
  recovery_window_in_days = 0 
}


resource "aws_secretsmanager_secret_version" "active_directory_password" {
  secret_id = aws_secretsmanager_secret.active_directory_password.id
  secret_string = "${random_password.active_directory_password.result}"
}



################################################################################
# Simulate Anycompany Corporate Directory 
################################################################################


resource "aws_directory_service_directory" "anycompany_ad" {
  name     = "anycompany.com"
  password = random_password.active_directory_password.result
  edition  = "Standard"
  type     = "MicrosoftAD"

  vpc_settings {
     vpc_id     = module.vpc.vpc_id
     subnet_ids = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
  }

  tags = local.tags
}



################################################################################
# Create AWS Managed Active Directory 
################################################################################

resource "aws_directory_service_directory" "managed_ad" {
  name     = "managed-ad.com"
  password = random_password.active_directory_password.result
  edition  = "Standard"
  type     = "MicrosoftAD"

  vpc_settings {
     vpc_id     = module.vpc.vpc_id
     subnet_ids = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
  }

  tags = local.tags
}

################################################################################
# Setup One way Incoming trust from MANAGED-AD.COM to ANYCOMPANY.COM
################################################################################


resource "aws_directory_service_trust" "anycompany_ad" {
  directory_id = aws_directory_service_directory.anycompany_ad.id

  remote_domain_name = aws_directory_service_directory.managed_ad.name
  trust_direction    = "One-Way: Incoming"
  trust_password     = random_password.active_directory_password.result

  conditional_forwarder_ip_addrs = aws_directory_service_directory.managed_ad.dns_ip_addresses
}

resource "aws_directory_service_trust" "managed_ad" {
  directory_id = aws_directory_service_directory.managed_ad.id

  remote_domain_name = aws_directory_service_directory.anycompany_ad.name
  trust_direction    = "One-Way: Outgoing"
  trust_password     =  random_password.active_directory_password.result

  conditional_forwarder_ip_addrs = aws_directory_service_directory.anycompany_ad.dns_ip_addresses
}


#######################################################################################################
# Update Security groups for Active Directory domain controllers to accept traffic from the entire VPC
#######################################################################################################

resource "aws_security_group_rule" "allow-local-traffic-anycompany_ad" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = aws_directory_service_directory.anycompany_ad.security_group_id
  description       = "Domain Controllers to accept traffic from entire VPC"
}

resource "aws_security_group_rule" "allow-local-traffic-managed_ad" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = aws_directory_service_directory.managed_ad.security_group_id
  description       = "Domain Controllers to accept traffic from entire VPC"
}

