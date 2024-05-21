# Terraform Enterprise Flexible Deployment Options in External Services mode on AWS

# Prerequisites
* Install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

* AWS account

* TFE FDO license

# Diagram

![tfe_fdo_on_podman_in_external_services_mode](https://github.com/dmitryuchuvatov/terraform-amazon-tfe-fdo-podman-si/assets/119931089/f1c984ac-c083-4f43-ae64-0376a187f5bd)


# How To

## Clone repository

```
git clone https://github.com/dmitryuchuvatov/terraform-amazon-tfe-fdo-podman-si.git
```

## Change folder

```
cd terraform-amazon-tfe-fdo-podman-si
```

## Rename the file called `terraform.tfvars-sample` to `terraform.tfvars` and replace the values with your own.
The current content is below:

```
region              = "eu-west-3"                            # AWS region to deploy in
environment_name    = "tfe-fdo-podman-md"                    # Name of the environment, used in naming of resources
vpc_cidr            = "10.200.0.0/16"                        # The IP range for the VPC in CIDR format
route53_zone        = "tf-support.hashicorpdemo.com"         # The domain of your hosted zone in Route 53
route53_subdomain   = "tfe-fdo-podman-si"                    # The subdomain of the URL
cert_email          = "dmitry.uchuvatov@hashicorp.com"       # The email address used to register the certificate
database_name       = "fdo"                                  # PostgreSQL database name
postgresql_user     = "postgres"                             # PostgreSQL admin username
postgresql_password = "Password1#"                           # PostgreSQL admin password
tfe_release         = "v202404-2"                            # TFE release version (https://developer.hashicorp.com/terraform/enterprise/releases)
tfe_password        = "Password1#"                           # TFE encryption password
tfe_license         = "02MV4UU4..."                          # Value from the license file                                   
```

## Set AWS credentials

```
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SESSION_TOKEN=
```

## Terraform init
```
terraform init
```

## Terraform apply

```
terraform apply
```

When prompted, type **yes** and hit **Enter** to start provisioning AWS infrastructure and install TFE on it.

After some time, you should see the similar result:

```
Apply complete! Resources: 31 added, 0 changed, 0 destroyed.

Outputs:

tfe_login =  "https://tfe-fdo-podman-si.tf-support.hashicorpdemo.com"
ssh_login = "ssh -i tfesshkey.pem ec2-user@tfe-fdo-podman-si.tf-support.hashicorpdemo.com
```

## Next steps
It will take ~ 10 minutes to spin up TFE. You can verify this by clicking on the URL from the previous output.

When UI is accessible, [provision your first administrative user](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/initial-admin-user) and start using Terraform Enterprise.

