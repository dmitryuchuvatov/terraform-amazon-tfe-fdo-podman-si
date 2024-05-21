# VPC

resource "aws_vpc" "tfe" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.environment_name}-vpc"
  }
}

# Public Subnet #1
resource "aws_subnet" "tfe_public" {
  availability_zone = "${var.region}b"
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 0)
  vpc_id            = aws_vpc.tfe.id

  tags = {
    Name = "${var.environment_name}-subnet-public"
  }
}

# Private Subnet #1
resource "aws_subnet" "tfe_private1" {
  availability_zone = "${var.region}b"
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10)
  vpc_id            = aws_vpc.tfe.id

  tags = {
    Name = "${var.environment_name}-subnet-private1"
  }
}

# Private Subnet #2
resource "aws_subnet" "tfe_private2" {
  availability_zone = "${var.region}c"
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 11)
  vpc_id            = aws_vpc.tfe.id

  tags = {
    Name = "${var.environment_name}-subnet-private2"
  }
}

# IGW (Internet Gateway)

resource "aws_internet_gateway" "tfe_igw" {
  vpc_id = aws_vpc.tfe.id

  tags = {
    Name = "${var.environment_name}-igw"
  }
}

# Link IGW with Route Table

resource "aws_default_route_table" "tfe" {
  default_route_table_id = aws_vpc.tfe.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tfe_igw.id
  }

  tags = {
    Name = "${var.environment_name}-rtb"
  }
}

# Security Group

resource "aws_security_group" "tfe_sg" {
  name   = "${var.environment_name}-sg"
  vpc_id = aws_vpc.tfe.id

  tags = {
    Name = "${var.environment_name}-sg"
  }
}

resource "aws_security_group_rule" "allow_https_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.tfe_sg.id

  from_port   = "443"
  to_port     = "443"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.tfe_sg.id

  from_port   = "80"
  to_port     = "80"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_ssh_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.tfe_sg.id

  from_port   = "22"
  to_port     = "22"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_postgres_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.tfe_sg.id

  from_port   = "5432"
  to_port     = "5432"
  protocol    = "tcp"
  cidr_blocks = [aws_vpc.tfe.cidr_block]
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.tfe_sg.id

  from_port   = "0"
  to_port     = "0"
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

# Key Pair

resource "tls_private_key" "rsa-4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "tfe" {
  key_name   = "${var.environment_name}-keypair"
  public_key = tls_private_key.rsa-4096.public_key_openssh
}

resource "local_file" "tfesshkey" {
  content         = tls_private_key.rsa-4096.private_key_pem
  filename        = "${path.module}/tfesshkey.pem"
  file_permission = "0600"
}

# EC2

data "aws_ami" "redhat" {
  most_recent = true

  owners = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-9*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "tfe" {
  ami                    = data.aws_ami.redhat.image_id
  iam_instance_profile   = aws_iam_instance_profile.tfe_profile.name
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.tfe.key_name
  vpc_security_group_ids = [aws_security_group.tfe_sg.id]
  subnet_id              = aws_subnet.tfe_public.id

  root_block_device {
    volume_size = 60
    volume_type = "io1"
    iops        = "500"
  }


  user_data = templatefile("${path.module}/scripts/cloud-init.tpl", {
    route53_subdomain   = var.route53_subdomain
    route53_zone        = var.route53_zone
    database_name       = var.database_name
    postgresql_fqdn     = aws_db_instance.tfe.address
    postgresql_password = var.postgresql_password
    postgresql_user     = var.postgresql_user
    region              = var.region
    s3_bucket           = aws_s3_bucket.tfe_files.id
    tfe_password        = var.tfe_password
    tfe_release         = var.tfe_release
    tfe_license         = var.tfe_license
    full_chain          = base64encode("${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}")
    private_key_pem     = base64encode("${acme_certificate.certificate.private_key_pem}")
  })

  tags = {
    Name = "${var.environment_name}-ec2"
  }
}

# Public IP
resource "aws_eip" "eip_tfe" {
  vpc = true

  tags = {
    Name = "${var.environment_name}-eip"
  }
}

resource "aws_eip_association" "eip_assoc" {
  allocation_id = aws_eip.eip_tfe.id
  instance_id   = aws_instance.tfe.id
}

# DNS

data "aws_route53_zone" "selected" {
  name         = var.route53_zone
  private_zone = false
}

resource "aws_route53_record" "www" {
  name    = "${var.route53_subdomain}.${var.route53_zone}"
  records = [aws_eip.eip_tfe.public_ip]
  ttl     = "300"
  type    = "A"
  zone_id = data.aws_route53_zone.selected.zone_id
}

# SSL certificate

resource "tls_private_key" "cert_private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.cert_private_key.private_key_pem
  email_address   = var.cert_email
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = "${var.route53_subdomain}.${var.route53_zone}"

  dns_challenge {
    provider = "route53"

    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.selected.zone_id
    }
  }
}

resource "aws_acm_certificate" "cert" {
  private_key       = acme_certificate.certificate.private_key_pem
  certificate_body  = acme_certificate.certificate.certificate_pem
  certificate_chain = acme_certificate.certificate.issuer_pem
}

# IAM

resource "aws_iam_instance_profile" "tfe_profile" {
  name = "${var.environment_name}-profile"
  role = aws_iam_role.tfe_s3_role.name
}

resource "aws_iam_role" "tfe_s3_role" {
  name = "${var.environment_name}-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    tag-key = "${var.environment_name}-role"
  }
}

resource "aws_iam_policy" "tfe_s3_policy" {
  name = "${var.environment_name}-policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListStorageLensConfigurations",
          "s3:ListAccessPointsForObjectLambda",
          "s3:GetAccessPoint",
          "s3:PutAccountPublicAccessBlock",
          "s3:GetAccountPublicAccessBlock",
          "s3:ListAllMyBuckets",
          "s3:ListAccessPoints",
          "s3:PutAccessPointPublicAccessBlock",
          "s3:ListJobs",
          "s3:PutStorageLensConfiguration",
          "s3:ListMultiRegionAccessPoints",
          "s3:CreateJob"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "VisualEditor1",
        "Effect" : "Allow",
        "Action" : "s3:*",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.tfe_s3_role.name
  policy_arn = aws_iam_policy.tfe_s3_policy.arn
}

# S3 bucket
resource "aws_s3_bucket" "tfe_files" {
  bucket = "${var.environment_name}-bucket"

  tags = {
    Name = "${var.environment_name}-bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "tfe_files" {
  bucket = aws_s3_bucket.tfe_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# RDS
resource "aws_db_instance" "tfe" {
  allocated_storage      = 50
  db_name                = var.database_name
  db_subnet_group_name   = aws_db_subnet_group.tfe.name
  engine                 = "postgres"
  engine_version         = "14.10"
  identifier             = "${var.environment_name}-postgres"
  instance_class         = "db.m5.large"
  multi_az               = false
  password               = var.postgresql_password
  skip_final_snapshot    = true
  username               = var.postgresql_user
  vpc_security_group_ids = [aws_security_group.tfe_sg.id]

  tags = {
    Name = "${var.environment_name}-postgres"
  }
}

resource "aws_db_subnet_group" "tfe" {
  name       = "${var.environment_name}-subnetgroup"
  subnet_ids = [aws_subnet.tfe_private1.id, aws_subnet.tfe_private2.id]

  tags = {
    Name = "${var.environment_name}-subnetgroup"
  }
}