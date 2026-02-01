locals {
  config = jsondecode(file(var.config_file))
}

locals {
  project_name       = local.config.project_name
  aws_region         = local.config.aws_region
  vpc_cidr           = local.config.vpc_cidr
  public_subnet_cidr = local.config.public_subnet_cidr
  private_subnet_cidr = local.config.private_subnet_cidr
  instance_type      = local.config.instance_type
  environment        = local.config.environment
}

resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${local.project_name}-vpc"
    Environment = local.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.project_name}-public-subnet"
    Environment = local.environment
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = local.private_subnet_cidr

  tags = {
    Name        = "${local.project_name}-private-subnet"
    Environment = local.environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web_sg" {
  name        = "${local.project_name}-web-sg"
  description = "Allow HTTP inbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.project_name}-web-sg"
    Environment = local.environment
  }
}