# Authenticate Amazon RDS instances using on-premises Microsoft Active Directory and Kerberos 

Enabling single sign-on and centralized authentication of database users through your existing Microsoft Active Directory infrastructure. This terraform blueprint outlines how to integrate  on-premises Microsoft Active Directory with Amazon RDS using AWS Managed Microsoft AD. It facilitates Kerberos authentication for supported RDS database engines.

Amazon RDS supports Kerberos authentication for PostgreSQL, MySQL ,DB2 ,Oracle and SQL Server. Please see this link for complete list of supported Database Engines and regions https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RDS_Fea_Regions_DB-eng.Feature.KerberosAuthentication.html



## Solution Overview

This solution involves using AWS Managed Microsoft Active Directory (MANAGED-AD.COM) to establish Forest Level One way outgoing Trust (or Two Way Trust) to your On-Prem Active Directory (ANYCOMPANY.COM) 

Supported Database Engines can then be launched / modified to join  MANAGED-AD along with Kerberos Enabled. For database authorization, database level permissions are created for respective ANYCOMPANY groups and/or AD users 

For more on Trusts see this link : https://aws.amazon.com/blogs/security/everything-you-wanted-to-know-about-trusts-with-aws-managed-microsoft-ad/

## Architecture

![Alt text](docs/rds-byoad.jpg?raw=true "Optional Title")


## Solution Details 

This codebase uses terraform to deploy the architecture above. 

1. It deploys 2 active directories and establishes Forest Level One-way Trust between these two directories. 
    i. ANYCOMPANY.COM is assumed to be On-Prem AD 
    ii. MANAGED-AD.COM is assumed to be AWS Managed AD 

2. This solution creates Aurora PostgreSQL serverless instance which joins MANAGED-AD

3. Optionally you can use this solution to create RDS for DB2 instance which joins MANAGED-AD by providing IBM license information. 

For more details on IBM Licensing see :  https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/db2-licensing.html#db2-licensing-options-byol

3. It also creates a Windows virtual desktop using Amazon Workspaces to be used as end user desktop, for User ID "Admin" . This desktop is joined to On-Prem Active directory ANYCOMPANY.COM

4. We create local permissions for user "Admin" in Aurora PostgreSQL database and  RDS for DB2 database (if deployed) 

5. Optional step  - We can also create local permissions for DBADMIN Group in Aurora PostgreSQL database and  RDS for DB2 database (if deployed). We then log onto ANYCOMPANY Active directory Domain controller and create a DBADMIN User group make User ID "Admin" a member of this group.

6. Lastly, we deploy database clients on Windows virtual desktop  (PG Admin for PostgreSQL and IBM Data Studio for DB2) and successfully test Kerberos Authentication

The setup in this solution can also be  applied for other RDS database engines that support Kerberos (MySQL,Oracle and SQL Server)


## Code Structure 

The project is structured as follows

    .
    ├── 1.locals.tf --> (default database Name, VPC configuration etc)
    ├── 2.vpc.tf --> (creates VPC,required subnets and configures security group rules )
    ├── 3.active-directory.tf --> (create 2  active directories ANYCOMPANY.COM and AWS-MANAGED.COM, Establishes trust between the two ADs and finally stores AD passwords in AWS Secrets Manager)
    ├── 4.databases.tf --> (deploys PostgreSQL serverless instance and joins it to AWS-MANAGED.COM, Database Admin password is stored in AWS Secrets Manager)
    ├── 5.workspaces.tf --> (creates virtual windows desktop for user ID : Admin, joins this desktop to external AD ANYCOMPANY.COM)


## Prerequisites :

Install terraform https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
Install git https://git-scm.com/downloads


## Getting Started - Please follow these instructions in sequence

### STEP 1. Infrastructure Deployment : Create required Infrastructure (Active Directory creation, Trust relationship, Databases and Virtual User Desktop )

clone the terraform repo
```
git clone https://github.com/aws-samples/rds-kerberos-authentication-using-onprem-active-directory
```
download dependencies
```
terraform init
```

With respect to database deployment we have 3 options  2. RDS for DB2 only 3. Both

  - Option 1 : Deploy Aurora PostgreSQL only

  ```
  terraform apply -var='deployAuroraPostgreSQL=Y' 
  ```

  - Option 2 : Deploy RDS for DB2 only.IBM Customer ID and Site ID are related to IBM DB2 licencisng details. See here for more info https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/db2-licensing.html#db2-licensing-options-byol
   

  ```
  terraform apply  -var='deployRdsForDb2={ibm_customer_id="XXXXXXXX",ibm_site_id="XXXXXX"}' 
  ```
  - Option 3 : Deploy both  Aurora PostgreSQL and RDS for DB2. IBM Customer ID and Site ID are related to IBM DB2 licencisng details. See here for more info https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/db2-licensing.html#db2-licensing-options-byol 

  ```
  terraform apply -var='deployAuroraPostgreSQL=Y' -var='deployRdsForDb2={ibm_customer_id="XXXXXXX",ibm_site_id="XXXXXXXXX"}'
  ```

Infrastructure creation ( AD creation, Trust relationship, Databases and Virtual User Desktop ) will taek about ~ 60 to 90 minutes.

#####  Output should look like below  

```
Apply complete! Resources: 48 added, 0 changed, 0 destroyed.

Outputs:

```

#####  Recommended : Control which IP addresses your WorkSpaces can be accessed from  

Amazon WorkSpaces allows you to control which IP addresses your WorkSpaces can be accessed from. By using IP address-based control groups, you can define and manage groups of trusted IP addresses, and only allow users to access their WorkSpaces when they're connected to a trusted network. See more details here https://docs.aws.amazon.com/workspaces/latest/adminguide/amazon-workspaces-ip-access-control-groups.html

### STEP 2. Login as a user to Windows Virtual Desktop and  download & configure Database clients ( PGAdmin4 and IBM Data Studio ) :

1. Download Amazon Workspaces client : https://clients.amazonworkspaces.com/
2. go to AWS console --> Amazon Workspaces and click on the workspace ID created for the user Admin --> note the registration code . Note this information is also available in the Terraform console output (Step #1 above)

![Alt text](docs/Workspaces-registration-code.png?raw=true "Optional Title")

3. Go to AWS Secrets Manager and get the password. The password for Virtual desktop is same as active_directory_password for AD Domain controllers


![Alt text](docs/active-directory-dc-password.png?raw=true "Optional Title")


4. Login to the Virtual desktop using the workspaces app 

![Alt text](docs/Workspaces-enter-registation-code.png?raw=true "Optional Title")

![Alt text](docs/Workspaces-login.png?raw=true "Optional Title")

5. Create Kerberos Configuration file :  Go to C:\Windows and create krb5.ini file  and update it as below. This is kerberos configuration file. 

For more details, see https://www.ibm.com/docs/en/was/8.5.5?topic=scripting-kerberos-configuration-file 


```
[libdefaults]
default_realm = ANYCOMPANY.COM

[realms]
ANYCOMPANY.com = {
kdc = anycompany.com
admin_server = anycompany.com
}

MANAGED-AD.COM = {
kdc = managed-ad.com
admin_server = managed-ad.com
}

[domain_realm]
.anycompany.com = ANYCOMPANY.COM
anycompany.com = ANYCOMPANY.COM
.managed-ad.com = MANAGED_AD.COM
managed-ad.com = MANAGED-AD.COM
.rds.amazonaws.com = MANAGED-AD.COM

[capaths]
ANYCOMPANY.COM = {
    MANAGED-AD.COM = .
}
MANAGED-AD.COM = {
    ANYCOMPANY.COM = .
}
```

6. Download PG Admin for PostgreSQL  : https://www.pgadmin.org and enable it Kerberos authentication by updating AUTHENTICATION_SOURCES to [‘kerberos’, ‘internal’] in cofig.py configuration file. [‘kerberos’, ‘internal’].The location of file is on web subfolder of pgAdmin4 installation. see example screenshot below. 
For more details go to https://www.pgadmin.org/docs/pgadmin4/development/kerberos.html

![Alt text](docs/pgadmin4-config-py-location.png?raw=true "Optional Title")

![Alt text](docs/pgadmin4-kerberos-config.png?raw=true "Optional Title")


7. For DB2 download IBM Data Studio : https://www.youtube.com/watch?v=1b85FX8qyP4. 

   Follow additional steps here https://www.ibm.com/docs/en/db2-big-sql/7.0?topic=authentication-configuring-jdbc-clients-kerberos-client#admin_kerb_jdbc to configure JAAS confguration file to use kerberos


### STEP 3. Create local users in the database - Using the Database Clients installed on Windows Virtual desktop

1. Get master database user and password from AWS secrets manager for both PostgreSQL and DB2 
2. For PostgreSQL - create a local database user for Kerberos Principal Admin@ANYCOMPANY.COM - Follow Step #7 on this link https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/postgresql-kerberos-setting-up.html#postgresql-kerberos-setting-up.create-users


Login to PGAdmin4 using Master username and password and open PSAL. see this link on  how to open PSQL in PGAdmin : https://www.pgadmin.org/docs/pgadmin4/8.9/psql_tool.html

```
testdb=> CREATE USER "Admin@ANYCOMPANY.COM" WITH LOGIN;

tesdb=> GRANT rds_ad TO "Admin@ANYCOMPANY.COM";
```
3. From IBM Data studio - connect to DB2 using Master database and Password and create new user ADMIN  and grant it connect priviledges. See this video for more details on how to do so : https://www.youtube.com/watch?v=atT4YLFvzDM

![Alt text](docs/db2-create-user.png?raw=true "Optional Title")

### STEP 4. Test Kerberos

1. Close  Database clients PGAdmin4 and / or IBM Data Studtio
2. Reopen them by using elevated priviledges : rightclick  --> Run as administrator 

![Alt text](docs/run-as-admin.png?raw=true "Optional Title")

3. For PostgreSQL

  open Command line tool as Administrator and run the following klist command to get Kerberos ticket for Postgres Database server ( on AWS Managed AD )

  NOTE - This is a workaround to get Kerberos ticket for MANAGED-AD.COM manually. PGAdmin4 should ideally execute this step on its own, however we have discovered that is not happening. Hence the need for this step. See known issues for more details

  ```
  klist get postgres/<database_endpoint>@MANAGED-AD.COM 

  ```
  enter database details as shown and select Kerberos and hit save. The connection should be successful

  ![Alt text](docs/pgadmin4-postgres-kerberos.png?raw=true "Optional Title")


4. For RDS for DB2 : IBM Data Studio   --> new connection  --> IBM Data Server Driver for JDBC and SQLJ using Kerberos security Default  --> enter database and endpoint --> select Use Cached TGT --> Test Connection 

The connection should succeed as shown below 

![Alt text](docs/rds-for-db2-kerberos.png?=true "Optional Title")


STEP 4. Destroy

To teardown and remove the resources created in this example:

```sh
terraform destroy -auto-approve
```

## Troubleshooting and Known Issues 

PGAdmin4 is unable to request kerberos ticket from MANAGED-AD.COM so as a workaround run the following command manually from windows command prompt 

 ```
  klist get postgres/<database_endpoint>@MANAGED-AD.COM 

  ```

## Support & Feedback

This project is maintained by AWS Solution Architects. It is not part of an AWS service and support is provided on best-effort basis. To post feedback, submit feature ideas, report bugs and contribute, please  see the [Contribution guide](./CONTRIBUTING.md).


## Security

See [CONTRIBUTING](./CONTRIBUTING.md#security-issue-notifications) for more information.

## License

Apache-2.0 Licensed. See [LICENSE](./LICENSE).
