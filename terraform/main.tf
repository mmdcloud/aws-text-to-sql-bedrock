# VPC Configuration
module "vpc" {
  source                = "./modules/vpc/vpc"
  vpc_name              = "mediaconvert-vpc"
  vpc_cidr_block        = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  internet_gateway_name = "vpc_igw"
}

# Security Group
module "security_group" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = "mediaconvert-security-group"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "any"
    },
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "any"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Public Subnets
module "public_subnets" {
  source = "./modules/vpc/subnets"
  name   = "mediaconvert-public-subnet"
  subnets = [
    {
      subnet = "10.0.1.0/24"
      az     = "us-east-1a"
    },
    {
      subnet = "10.0.2.0/24"
      az     = "us-east-1b"
    },
    {
      subnet = "10.0.3.0/24"
      az     = "us-east-1c"
    }
  ]
  vpc_id                  = module.vpc.vpc_id
  map_public_ip_on_launch = true
}

# Private Subnets
module "private_subnets" {
  source = "./modules/vpc/subnets"
  name   = "mediaconvert-private-subnet"
  subnets = [
    {
      subnet = "10.0.6.0/24"
      az     = "us-east-1d"
    },
    {
      subnet = "10.0.5.0/24"
      az     = "us-east-1e"
    },
    {
      subnet = "10.0.4.0/24"
      az     = "us-east-1f"
    }
  ]
  vpc_id                  = module.vpc.vpc_id
  map_public_ip_on_launch = false
}

# Public Route Table
module "public_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "mediaconvert-public-route-table"
  subnets = module.public_subnets.subnets[*]
  routes = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = module.vpc.igw_id
    }
  ]
  vpc_id = module.vpc.vpc_id
}

# Private Route Table
module "private_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "mediaconvert-private-route-table"
  subnets = module.private_subnets.subnets[*]
  routes  = []
  vpc_id  = module.vpc.vpc_id
}

# Frontend Module
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 IAM Instance Profile
data "aws_iam_policy_document" "instance_profile_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "instance_profile_iam_role" {
  name               = "instance-profile-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.instance_profile_assume_role.json
}

data "aws_iam_policy_document" "instance_profile_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "instance_profile_s3_policy" {
  role   = aws_iam_role.instance_profile_iam_role.name
  policy = data.aws_iam_policy_document.instance_profile_policy_document.json
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam-instance-profile"
  role = aws_iam_role.instance_profile_iam_role.name
}

module "frontend_instance" {
  source                      = "./modules/ec2"
  name                        = "frontend-instance"
  ami_id                      = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = "madmaxkeypair"
  associate_public_ip_address = true
  user_data                   = filebase64("${path.module}/scripts/user_data.sh")
  instance_profile            = aws_iam_instance_profile.iam_instance_profile.name
  subnet_id                   = module.public_subnets.subnets[0].id
  security_groups             = [module.security_group.id]
}

module "blog_storage_bucket" {
  source             = "./modules/s3"
  bucket_name        = "blogstoragebucket"
  objects            = []
  versioning_enabled = "Enabled"
  bucket_notification = {
    queue           = []
    lambda_function = []
  }
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST", "GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  force_destroy = true
}

# Lambda Function Code Bucket
module "lambda_function_code_bucket" {
  source      = "./modules/s3"
  bucket_name = "lambdafunctioncodebucket"
  objects = [
    {
      key    = "lambda_function.zip"
      source = "./files/lambda_function.zip"
    }
  ]
  versioning_enabled = "Enabled"
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST", "GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  force_destroy = true
}

# Lambda function IAM Role
module "lambda_function_iam_role" {
  source             = "./modules/iam"
  role_name          = "lambda_function_iam_role"
  role_description   = "lambda_function_iam_role"
  policy_name        = "lambda_function_iam_policy"
  policy_description = "lambda_function_iam_policy"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "lambda.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
  policy             = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*",
            "Effect": "Allow"
        }
      ]
    }
    EOF
}

# Lambda function to generate response and store them to s3
module "lambda_function" {
  source        = "./modules/lambda"
  function_name = "lambda_function"
  role_arn      = module.lambda_function_iam_role.arn
  env_variables = {}
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  s3_bucket     = module.lambda_function_code_bucket.bucket
  s3_key        = "lambda_function.zip"
  depends_on    = [module.lambda_function_code_bucket]
}

# API Gateway configuration
resource "aws_api_gateway_rest_api" "blog_api" {
  name = "blog-api"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "resource_api" {
  rest_api_id = aws_api_gateway_rest_api.blog_api.id
  parent_id   = aws_api_gateway_rest_api.blog_api.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_method" "blog_api_method" {
  rest_api_id      = aws_api_gateway_rest_api.blog_api.id
  resource_id      = aws_api_gateway_resource.resource_api.id
  api_key_required = false
  http_method      = "POST"
  authorization    = "NONE"
}

resource "aws_api_gateway_integration" "resource_api_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.blog_api.id
  resource_id             = aws_api_gateway_resource.resource_api.id
  http_method             = aws_api_gateway_method.blog_api_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_function.invoke_arn
}

resource "aws_api_gateway_method_response" "resource_api_method_response" {
  rest_api_id = aws_api_gateway_rest_api.blog_api.id
  resource_id = aws_api_gateway_resource.resource_api.id
  http_method = aws_api_gateway_method.blog_api_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "resource_api_method_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.blog_api.id
  resource_id = aws_api_gateway_resource.resource_api.id
  http_method = aws_api_gateway_method.blog_api_method.http_method
  status_code = aws_api_gateway_method_response.resource_api_method_response.status_code
  depends_on = [
    aws_api_gateway_integration.resource_api_method_integration
  ]
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.blog_api.id
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_api_gateway_integration.resource_api_method_integration, aws_api_gateway_integration.resource_api_method_integration]
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.blog_api.id
  stage_name    = "dev"
}