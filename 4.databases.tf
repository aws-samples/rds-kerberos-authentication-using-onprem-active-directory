
#######################################################################################
# DB subnet group for Databases 
#######################################################################################

resource "aws_db_subnet_group" "this" {
  name        = "${lower(local.name)}"
  
  description = "For Databases  ${local.name}"
  subnet_ids  = module.vpc.private_subnets 
  tags = local.tags
}

#######################################################################################
# Create IAM role for database for RDS to access AWS Managed Directory service domains
#######################################################################################

resource "aws_iam_role" "rds_managed_ad_role" {
  name = "rds_aws_managed_active_directory_role2"
  assume_role_policy =  jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
        {
            "Sid" =  "",
            "Effect" = "Allow",
            "Principal" = {
                "Service" = [
                    "directoryservice.rds.eu-central-2.amazonaws.com",
                    "directoryservice.rds.eu-south-1.amazonaws.com",
                    "directoryservice.rds.me-south-1.amazonaws.com",
                    "directoryservice.rds.ap-southeast-4.amazonaws.com",
                    "directoryservice.rds.ap-south-2.amazonaws.com",
                    "directoryservice.rds.af-south-1.amazonaws.com",
                    "directoryservice.rds.amazonaws.com",
                    "directoryservice.rds.ap-east-1.amazonaws.com",
                    "directoryservice.rds.il-central-1.amazonaws.com",
                    "directoryservice.rds.eu-south-2.amazonaws.com",
                    "directoryservice.rds.ap-southeast-3.amazonaws.com",
                    "rds.amazonaws.com",
                    "directoryservice.rds.me-central-1.amazonaws.com"
                ]
            },
            "Action" = "sts:AssumeRole"
        }
    ]
})
  
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonRDSDirectoryServiceAccess"]   # ARN for managed policy for Directory service access 

  tags = local.tags

}

################################################################################
# Provision Aurora PostgreSQL Serverless v2 
################################################################################

data "aws_rds_engine_version" "postgresql" {
  engine  = "aurora-postgresql"
  version = "14.5"
}

module "aurora_postgresql_v2" {
  count = var.deployAuroraPostgreSQL == "Y" ? 1 : 0 // Only deploy this module if deploy_aurora_postgresql flage is Y
  //source = "terraform-aws-modules/rds-aurora/aws" 
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-rds-aurora.git?ref=234257ca8ebdf1f08962c909030cd9751625695c" # fixed vulnerability https://docs.prismacloud.io/en/enterprise-edition/policy-reference/supply-chain-policies/terraform-policies/ensure-terraform-module-sources-use-git-url-with-commit-hash-revision
  name              = "${lower(local.database_name)}-${lower(local.anycompanyad_name)}-aurora-postgresqlv2"
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_mode       = "provisioned"
  engine_version    = data.aws_rds_engine_version.postgresql.version
  storage_encrypted = true
  master_username   = "Administrator"
  database_name     = local.database_name//VD : create a default DB with the name testdb
  domain = aws_directory_service_directory.managed_ad.id //VD : join DB to Managed active directory
  domain_iam_role_name = aws_iam_role.rds_managed_ad_role.name // IAM role required to Access managed active directory
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = aws_db_subnet_group.this.name
  create_security_group      = false // VD : use existing security group
  vpc_security_group_ids     = [module.vpc.default_security_group_id] // VD : use VPC default  security group whcih allows DB server to register with MANAGED-AD
  monitoring_interval = 60

  apply_immediately   = true # apply changes immediately without waiting for next maintenance window 
  skip_final_snapshot = true #for production environments turn this to flase 

  serverlessv2_scaling_configuration = {
    min_capacity = 1
    max_capacity = 1
  }

  instance_class = "db.serverless" // VD Aurora serverless 
  instances = {
    one = {}
    two = {}
  }

  # ensure AD and IAM role creation is complete prior to the Database creation
  depends_on = [
   module.vpc, 
   aws_iam_role.rds_managed_ad_role,
   aws_directory_service_directory.managed_ad
  ] 
  tags = local.tags
}


################################################################################
# Provision RDS DB2 Database
################################################################################

module "rds" {
  count = var.deployRdsForDb2.ibm_customer_id == "do not deploy db2" ? 0 : 1 // Only deploy this module if IBM licensing details are provided 
  # source = "terraform-aws-modules/rds/aws"
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-rds.git?ref=a76a3cd92220b91eaa467a5328db6f2c21e1fdee" # Fixed vulnerability https://docs.prismacloud.io/en/enterprise-edition/policy-reference/supply-chain-policies/terraform-policies/ensure-terraform-module-sources-use-git-url-with-commit-hash-revision
  identifier = "${lower(local.database_name)}-${lower(local.anycompanyad_name)}-db2"
  engine            = "db2-se"
  create_db_option_group = false
  instance_class    = "db.m6i.large"
  allocated_storage = 20
  db_name  = lower(local.database_name)
  username = "Administrator"
  domain = aws_directory_service_directory.managed_ad.id //VD : join DB to Managed active directory
  domain_iam_role_name = aws_iam_role.rds_managed_ad_role.name // IAM role required to Access managed active directory
  db_subnet_group_name = aws_db_subnet_group.this.name
  apply_immediately = true # apply changes immediately without waiting for next maintenance window 
  skip_final_snapshot = true #for production environments turn this to flase 
  family = local.db2_family

 
  parameter_group_name = "db2-ibm-customer-site-id"
  
  parameters = [
    {
    name = "rds.ibm_customer_id"
    value = var.deployRdsForDb2.ibm_customer_id
    },
    {
    name = "rds.ibm_site_id"
    value = var.deployRdsForDb2.ibm_site_id
    }
  ]
  #ensure AD and IAM role creation is complete prior to the Database creation
  depends_on = [
   module.vpc,  
   aws_iam_role.rds_managed_ad_role,
   aws_directory_service_directory.managed_ad
  ]
  }