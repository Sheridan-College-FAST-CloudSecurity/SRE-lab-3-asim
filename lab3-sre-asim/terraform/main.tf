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

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"  
  availability_zone       = "${local.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.project_name}-public-subnet-az2"
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

resource "aws_route_table_association" "public_assoc_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web_sg" {
  name        = "${local.project_name}-web-sg"
  description = "Allow HTTP only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
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


data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  owners = ["137112412989"]
}

resource "aws_secretsmanager_secret" "db_password" {
  name        = "${local.project_name}-db-password-v2"
  description = "Sample database password"
}

resource "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "lab_user"
    password = "Password123"
  })
}

resource "aws_security_group" "alb_sg" {
  name        = "${local.project_name}-alb-sg"
  description = "Allow HTTP from the internet to ALB"
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
    Name        = "${local.project_name}-alb-sg"
    Environment = local.environment
  }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "${local.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${local.project_name}-tg"
    Environment = local.environment
  }
}

resource "aws_lb" "web_alb" {
  name               = "${local.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [
    aws_subnet.public.id,
    aws_subnet.public_az2.id
  ]

  tags = {
    Name        = "${local.project_name}-alb"
    Environment = local.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

resource "aws_launch_template" "web_lt" {
  name_prefix   = "${local.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = local.instance_type

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(templatefile("${path.module}/../app/user-data.sh", {
    ENVIRONMENT = local.environment
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${local.project_name}-web"
      Environment = local.environment
    }
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name                      = "${local.project_name}-asg"
  max_size                  = 3
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.public.id, aws_subnet.public_az2.id]
  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  tag {
    key                 = "Name"
    value               = "${local.project_name}-web"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_lifecycle_hook" "terminate_hook" {
  name                   = "${local.project_name}-terminate-hook"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = 300
  default_result         = "CONTINUE"
}

resource "aws_db_instance" "app_db" {
  identifier              = "${local.project_name}-db"
  engine                  = "mysql"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = "lab_user"
  password                = "Password123!"
  db_name                 = "labdb"
  multi_az                = true
  backup_retention_period = 7
  skip_final_snapshot     = true
}

