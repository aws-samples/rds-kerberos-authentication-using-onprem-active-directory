
################################################################################
# Supporting VPC Resources
################################################################################

module "vpc" {
  #source  = "terraform-aws-modules/vpc/aws"
  #version = "~> 4.0"
  source =  "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=e226cc15a7b8f62fd0e108792fea66fa85bcb4b9" # fixed vulnerability https://docs.prismacloud.io/en/enterprise-edition/policy-reference/supply-chain-policies/terraform-policies/ensure-terraform-module-sources-use-git-url-with-commit-hash-revision 
  name = "${local.name}-${local.suffix}"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "private-subnet-for-directory-services" = 1 
  }

  private_subnet_tags = {
    "private-subnets-for-rds" = 1 
  }

  map_public_ip_on_launch = true  // Allow public subnets to auto allocate public Ips to launched instances.

  tags = local.tags
}



################################################################################
# Update Default Security groups to accept traffic from the entire VPC. 
# This is to esnure that RDS DB2 which will use this default SG is able to reach active directory 
################################################################################

resource "aws_security_group_rule" "allow-local-traffic-vpc-ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = module.vpc.default_security_group_id
  description       = "allow local traffic within VPC"
}

resource "aws_security_group_rule" "allow-local-traffic-vpc-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = module.vpc.default_security_group_id
  description       = "allow local traffic within VPC"
}