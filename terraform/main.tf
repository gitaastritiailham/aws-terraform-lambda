provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "plab_vpc" {
  cidr_block           = "10.11.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "plab_vpc"
  }
}

# Subnets
resource "aws_subnet" "pub_a" {
  vpc_id                  = aws_vpc.plab_vpc.id
  cidr_block              = "10.11.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "plab_pub_a"
  }
}

resource "aws_subnet" "pub_b" {
  vpc_id                  = aws_vpc.plab_vpc.id
  cidr_block              = "10.11.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "plab_pub_b"
  }
}

resource "aws_subnet" "pri_a" {
  vpc_id            = aws_vpc.plab_vpc.id
  cidr_block        = "10.11.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "plab_pri_a"
  }
}

resource "aws_subnet" "pri_b" {
  vpc_id            = aws_vpc.plab_vpc.id
  cidr_block        = "10.11.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "plab_pri_b"
  }
}

resource "aws_subnet" "pri_rds" {
  vpc_id            = aws_vpc.plab_vpc.id
  cidr_block        = "10.11.5.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "plab_pri_rds"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.plab_vpc.id

  tags = {
    Name = "plab_igw"
  }
}

# Elastic IP
resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = {
    Name = "${var.class_no}_eip_a"
  }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"

  tags = {
    Name = "${var.class_no}_eip_b"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "natgw_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.pub_a.id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = {
    Name = "${var.class_no}_natgw_a"
  }
}

resource "aws_nat_gateway" "natgw_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.pub_b.id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = {
    Name = "${var.class_no}_natgw_b"
  }
}

# Route Tables
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.plab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.class_no}_pub_rt"
  }
}

resource "aws_route_table" "pri_rt_a" {
  vpc_id = aws_vpc.plab_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw_a.id
  }

  tags = {
    Name = "${var.class_no}_pri_rt_a"
  }
}

resource "aws_route_table" "pri_rt_b" {
  vpc_id = aws_vpc.plab_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw_b.id
  }

  tags = {
    Name = "${var.class_no}_pri_rt_b"
  }
}

resource "aws_route_table" "rds_rt" {
  vpc_id = aws_vpc.plab_vpc.id

  tags = {
    Name = "${var.class_no}_rds_rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.pub_a.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.pub_b.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "pri_a" {
  subnet_id      = aws_subnet.pri_a.id
  route_table_id = aws_route_table.pri_rt_a.id
}

resource "aws_route_table_association" "pri_b" {
  subnet_id      = aws_subnet.pri_b.id
  route_table_id = aws_route_table.pri_rt_b.id
}

resource "aws_route_table_association" "pri_rds" {
  subnet_id      = aws_subnet.pri_rds.id
  route_table_id = aws_route_table.rds_rt.id
}

# Security Group Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "${var.class_no}_plab_lambda_sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.plab_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group RDS
resource "aws_security_group" "rdssg" {
  name        = "${var.class_no}_plab_rdssg"
  description = "security group for plab rds"
  vpc_id      = aws_vpc.plab_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_subg" {
  name       = "${var.class_no}_rds_subg"

  subnet_ids = [
    aws_subnet.pri_a.id,
    aws_subnet.pri_b.id,
    aws_subnet.pri_rds.id
  ]

  tags = {
    Name = "plab_rds_subg"
  }
}

# RDS
resource "aws_db_instance" "rds" {
  identifier             = "${var.class_no}-plab-db"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"

  username = "root"
  password = var.db_password

  db_name = "${var.class_no}_db"

  db_subnet_group_name   = aws_db_subnet_group.rds_subg.name
  vpc_security_group_ids = [aws_security_group.rdssg.id]
  
  availability_zone = "us-east-1a" 

  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name = "plab-db"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.class_no}_plab_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Deploy Package
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda.zip"
}

# Lambda Function
resource "aws_lambda_function" "products_api_clean_data" {
  function_name    = "${var.class_no}_plab_products"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  vpc_config {
    subnet_ids         = [aws_subnet.pri_a.id, aws_subnet.pri_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST = aws_db_instance.rds.address
      DB_USER = aws_db_instance.rds.username
      DB_PASS = aws_db_instance.rds.password
      DB_NAME = aws_db_instance.rds.db_name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_db_instance.rds
  ]
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api_new" {
  name          = "${var.class_no}_plab_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api_new.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.products_api_clean_data.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "products_route" {
  api_id    = aws_apigatewayv2_api.http_api_new.id
  route_key = "GET /products"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api_new.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.products_api_clean_data.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api_new.execution_arn}/*/*"
}