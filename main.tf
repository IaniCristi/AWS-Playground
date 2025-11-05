terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"  # Change to your preferred region
}

# VPC and networking (using default VPC for simplicity)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for RDS
resource "aws_security_group" "postgres_sg" {
  name        = "postgres-rds-sg"
  description = "Security group for PostgreSQL RDS instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "PostgreSQL access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # WARNING: Restrict this to your IP range in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "postgres-rds-sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "postgres_subnet" {
  name       = "postgres-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "postgres-subnet-group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier             = "my-postgres-db"
  engine                 = "postgres"
  engine_version         = "17.6"  # Updated to available version
  instance_class         = "db.t3.micro"  # Free tier eligible
  allocated_storage      = 20
  max_allocated_storage  = 100  # Enable storage autoscaling
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name  = "myappdb"
  username = "dbadmin"
  password = var.db_password  # Use variable for security

  db_subnet_group_name   = aws_db_subnet_group.postgres_subnet.name
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  publicly_accessible    = true  # Set to false for production

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  skip_final_snapshot       = true  # Set to false for production
  final_snapshot_identifier = "my-postgres-db-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name        = "my-postgres-db"
    Environment = "development"
  }
}

# Variables
variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
}

# Outputs
output "db_endpoint" {
  description = "PostgreSQL database endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}

output "db_username" {
  description = "Database username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "db_port" {
  description = "Database port"
  value       = aws_db_instance.postgres.port
}
