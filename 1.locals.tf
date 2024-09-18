provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

resource "random_string" "random" {
  length           = 4
  special          = true
  override_special = "~!@#$%^&*()`=-"
}

################################################################################
# Locals - default database Name, VPC configuration etc.
################################################################################
locals {
  name      = "byoad"
  region    = "us-east-1"
  vpc_cidr  = "10.0.0.0/16"
  azs       = slice(data.aws_availability_zones.available.names, 0, 3)
  database_name = "testdb"
  anycompanyad_name = "ANYCOMPANY" // Name of Corporate active directory 
  tags = {
    Blueprint  = local.name
    GithubRepo = ""
    Author ="VD"
  }
  suffix    = lower(random_string.random.result)
  db2_family = "db2-se-11.5"
    
}


