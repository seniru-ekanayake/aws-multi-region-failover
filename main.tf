# ------------------------------------------------------------------------------
# 1. THE SETUP
# ------------------------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # --- NEW PART: REMOTE BACKEND ---
  backend "s3" {
    bucket = "terraform-state-seniru-123"  
    key    = "global/s3/terraform.tfstate"
    region = "us-east-1"
  }
  # --------------------------------
}

# Provider 1: US East (Virginia)
provider "aws" {
  region = "us-east-1"
  alias  = "primary"
}

# Provider 2: US West (Oregon)
provider "aws" {
  region = "us-west-2"
  alias  = "secondary"
}

# ------------------------------------------------------------------------------
# REGION 1: US-EAST-1 (Virginia)
# ------------------------------------------------------------------------------

resource "aws_vpc" "vpc_primary" {
  provider             = aws.primary
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "vpc-primary" }
}

resource "aws_internet_gateway" "igw_primary" {
  provider = aws.primary
  vpc_id   = aws_vpc.vpc_primary.id
}

resource "aws_subnet" "subnet_primary" {
  provider                = aws.primary
  vpc_id                  = aws_vpc.vpc_primary.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_route_table" "rt_primary" {
  provider = aws.primary
  vpc_id   = aws_vpc.vpc_primary.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_primary.id
  }
}

resource "aws_route_table_association" "rta_primary" {
  provider       = aws.primary
  subnet_id      = aws_subnet.subnet_primary.id
  route_table_id = aws_route_table.rt_primary.id
}

resource "aws_security_group" "sg_primary" {
  provider    = aws.primary
  name        = "sg_primary"
  vpc_id      = aws_vpc.vpc_primary.id

  # Allow HTTP (Web)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH (Debug) - ADDED THIS
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web_primary" {
  provider                    = aws.primary
  ami                         = "ami-04b70fa74e45c3917" # Ubuntu East
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_primary.id
  vpc_security_group_ids      = [aws_security_group.sg_primary.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              echo "<h1>REGION 1 (VIRGINIA) IS ONLINE</h1>" > /var/www/html/index.html
              systemctl start apache2
              EOF

  tags = { Name = "web-primary" }
}

# ------------------------------------------------------------------------------
# REGION 2: US-WEST-2 (Oregon)
# ------------------------------------------------------------------------------

resource "aws_vpc" "vpc_secondary" {
  provider             = aws.secondary
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "vpc-secondary" }
}

resource "aws_internet_gateway" "igw_secondary" {
  provider = aws.secondary
  vpc_id   = aws_vpc.vpc_secondary.id
}

resource "aws_subnet" "subnet_secondary" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.vpc_secondary.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"
}

resource "aws_route_table" "rt_secondary" {
  provider = aws.secondary
  vpc_id   = aws_vpc.vpc_secondary.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_secondary.id
  }
}

resource "aws_route_table_association" "rta_secondary" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.subnet_secondary.id
  route_table_id = aws_route_table.rt_secondary.id
}

resource "aws_security_group" "sg_secondary" {
  provider    = aws.secondary
  name        = "sg_secondary"
  vpc_id      = aws_vpc.vpc_secondary.id

  # Allow HTTP (Web)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH (Debug) - ADDED THIS
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web_secondary" {
  provider                    = aws.secondary
  ami                         = "ami-0786adace1541ca80" # Ubuntu West
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_secondary.id
  vpc_security_group_ids      = [aws_security_group.sg_secondary.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              echo "<h1>REGION 2 (OREGON) IS ONLINE</h1>" > /var/www/html/index.html
              systemctl start apache2
              EOF

  tags = { Name = "web-secondary" }
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------
output "primary_url" {
  value = "http://${aws_instance.web_primary.public_ip}"
}

output "secondary_url" {
  value = "http://${aws_instance.web_secondary.public_ip}"
}
