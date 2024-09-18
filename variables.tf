
variable "deployAuroraPostgreSQL" {
  description = "Y/N if you want to deploy AuroraPostgreSQL with kerberos`" 
  type        = string
  validation {
    condition     = contains(["Y", "N"], var.deployAuroraPostgreSQL)
    error_message = "Valid values are (Y, N)."
  } 
  default     = "N"
  }


variable "deployRdsForDb2" {
  description = "For RDS DB2 with kerberos \n Please make sure DB2 licensing details in this format {ibm_customer_id = \"XXXXXXX\", ibm_site_id = \"XXXXXXXXXX\"}  \n see https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/db2-licensing.html#db2-licensing-options-byol for more details"
  type = object({
    ibm_customer_id =  string
    ibm_site_id = string
  })
 
  default = {
    ibm_customer_id =  "do not deploy db2"
    ibm_site_id = "do not dpeloy db2"
    }
  } 
