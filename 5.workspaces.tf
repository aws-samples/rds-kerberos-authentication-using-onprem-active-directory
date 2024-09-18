
##################################################################################################################
# Simulate a User Desktop for testuser using Amazon Workspaces. Join this desktop to AWS Managed AD 
# Workspaces requires workspaces_DefaultRole IAM role. check if role exist role and create one if it doesnt exist 
###################################################################################################################

data "aws_iam_policy" "AmazonWorkSpacesServiceAccess" {
  name = "AmazonWorkSpacesServiceAccess"
}

data "aws_iam_policy" "AmazonWorkSpacesSelfServiceAccess" {
  name = "AmazonWorkSpacesSelfServiceAccess"
}

data "aws_iam_policy" "AmazonWorkSpacesPoolServiceAccess" {
  name = "AmazonWorkSpacesPoolServiceAccess"
}

data "aws_iam_role" "workspaces_DefaultRole" {
  name = "workspaces_DefaultRole"
}


resource "aws_iam_role" "workspaces_DefaultRole" {
  count =  data.aws_iam_role.workspaces_DefaultRole.id == null ? 1 : 0 # Do not create if workspaces_DefaultRole already exusts 
  name = "rds_aws_managed_active_directory_role2"
  assume_role_policy =  jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
        {
            "Effect" = "Allow",
            "Principal" = {
                "Service" = [
                    "workspaces.amazonaws.com"
                ]
            },
            "Action" = "sts:AssumeRole"
        }
    ]
})

  
  managed_policy_arns = [data.aws_iam_policy.AmazonWorkSpacesServiceAccess.arn,
                        data.aws_iam_policy.AmazonWorkSpacesSelfServiceAccess.arn,
                        data.aws_iam_policy.AmazonWorkSpacesPoolServiceAccess.arn ]   # ARN for managed policy for Directory service access 

  tags = local.tags

}


################################################################################
# External AD / ANYCOMPANY>COM has to be registered with Workspaces 
################################################################################

resource "aws_workspaces_directory" "workspaces_anycompany_ad" {
  directory_id = aws_directory_service_directory.anycompany_ad.id
  subnet_ids = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]
  depends_on = [
   module.vpc,  
   aws_directory_service_directory.anycompany_ad
  ]
  tags = local.tags
  
}

################################################################################
# Create Workspace
################################################################################


data "aws_workspaces_bundle" "value_windows_10" {
  bundle_id = "wsb-fb2xfp6r8" #Value with Windows 10 (Server 2019 based)
}

data "aws_kms_key" "workspaces" {
  key_id = "alias/aws/workspaces"
}



resource "aws_workspaces_workspace" "testuserdesktop" {
  directory_id = aws_workspaces_directory.workspaces_anycompany_ad.id
  bundle_id    = data.aws_workspaces_bundle.value_windows_10.id
  user_name    = "Admin" // User ID is Admin

  root_volume_encryption_enabled = true
  user_volume_encryption_enabled = true
  volume_encryption_key          = data.aws_kms_key.workspaces.arn

  workspace_properties {
    compute_type_name                         = "POWER"
    user_volume_size_gib                      = 100
    root_volume_size_gib                      = 175
    running_mode                              = "AUTO_STOP"
    running_mode_auto_stop_timeout_in_minutes = 60
  }

  tags = local.tags
  # ensure AD and IAM role creation is complete prior to the Database creation
  depends_on = [
   module.vpc,  
   aws_workspaces_directory.workspaces_anycompany_ad,
   aws_directory_service_directory.anycompany_ad
  ]
}