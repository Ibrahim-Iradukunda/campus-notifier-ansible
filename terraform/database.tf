data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

data "aws_subnet" "public" {
  id = sort(data.aws_subnets.public.ids)[0]
}

data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "database_admin" {
  key_name   = "campus-notifier-db-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name      = "campus-notifier-db-admin"
    ManagedBy = "Terraform"
  }
}

resource "aws_security_group" "database" {
  name        = "campus-notifier-database"
  description = "SSH from the database administrator; database access can be scoped to the app host."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from the administrator current public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.db_admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "campus-notifier-database"
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_to_database" {
  count = var.app_security_group_id == null ? 0 : 1

  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = var.app_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
  description                  = "Database traffic from the application security group"
}

resource "aws_instance" "database" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.database_instance_type
  subnet_id                   = data.aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.database.id]
  key_name                    = aws_key_pair.database_admin.key_name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name      = "campus-notifier-database"
    Role      = "database"
    ManagedBy = "Terraform"
  }
}
