data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

# ---------------------------------------------------------------------
# Registering vault provider
# ---------------------------------------------------------------------
data "vault_generic_secret" "rds" {
  path = "secret/rds"
}

# ---------------------------------------------------------------------
# VPC Configuration
# ---------------------------------------------------------------------
module "vpc" {
  source                = "./modules/vpc/vpc"
  vpc_name              = "vpc"
  vpc_cidr_block        = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  internet_gateway_name = "vpc_igw"
}

module "frontend_lb_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = "frontend-lb-sg"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTP traffic"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTPS traffic"
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

module "backend_lb_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = "backend-lb-sg"
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
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTPS traffic"
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

module "ecs_frontend_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = "ecs-frontend-sg"
  ingress = [
    {
      from_port       = 3000
      to_port         = 3000
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = []
      security_groups = [module.frontend_lb_sg.id]
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

module "ecs_backend_sg" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = "ecs-backend-sg"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = []
      security_groups = [module.backend_lb_sg.id]
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

module "rds_security_group" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = "rds-security-group"
  ingress = [
    {
      from_port       = 3306
      to_port         = 3306
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
  name   = "public-subnet"
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
  name   = "private-subnet"
  subnets = [
    {
      subnet = "10.0.6.0/24"
      az     = "us-east-1c"
    },
    {
      subnet = "10.0.5.0/24"
      az     = "us-east-1b"
    },
    {
      subnet = "10.0.4.0/24"
      az     = "us-east-1a"
    }
  ]
  vpc_id                  = module.vpc.vpc_id
  map_public_ip_on_launch = false
}

# Public Route Table
module "public_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "public-route-table"
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
  name    = "private-route-table"
  subnets = module.private_subnets.subnets[*]
  routes  = []
  vpc_id  = module.vpc.vpc_id
}

# ---------------------------------------------------------------------
# Cognito Configuration
# ---------------------------------------------------------------------
module "cognito" {
  source                     = "./modules/cognito"
  name                       = "text-to-sql-users"
  username_attributes        = ["email"]
  auto_verified_attributes   = ["email"]
  password_minimum_length    = 8
  password_require_lowercase = true
  password_require_numbers   = true
  password_require_symbols   = true
  password_require_uppercase = true
  schema = [
    {
      attribute_data_type = "String"
      name                = "email"
      required            = true
    }
  ]
  verification_message_template_default_email_option = "CONFIRM_WITH_CODE"
  verification_email_subject                         = "Verify your email for TextToSQL"
  verification_email_message                         = "Your verification code is {####}"
  user_pool_clients = [
    {
      name                                 = "texttosql_client"
      generate_secret                      = false
      explicit_auth_flows                  = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
      allowed_oauth_flows_user_pool_client = true
      allowed_oauth_flows                  = ["code", "implicit"]
      allowed_oauth_scopes                 = ["email", "openid"]
      callback_urls                        = ["https://example.com/callback"]
      logout_urls                          = ["https://example.com/logout"]
      supported_identity_providers         = ["COGNITO"]
    }
  ]
}

# -----------------------------------------------------------------------------------------
# Secrets Manager
# -----------------------------------------------------------------------------------------
module "db_credentials" {
  source                  = "./modules/secrets-manager"
  name                    = "rds_secrets"
  description             = "rds_secrets"
  recovery_window_in_days = 0
  secret_string = jsonencode({
    username = tostring(data.vault_generic_secret.rds.data["username"])
    password = tostring(data.vault_generic_secret.rds.data["password"])
  })
}

# -----------------------------------------------------------------------------------------
# S3 Module
# -----------------------------------------------------------------------------------------
module "bedrock_knowledge_base_data_source" {
  source        = "./modules/s3"
  bucket_name   = "bedrock-knowledge-base-data-source"
  objects       = []
  bucket_policy = ""
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    },
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  versioning_enabled = "Enabled"
  force_destroy      = true
}

# -----------------------------------------------------------------------------------------
# ECR Module
# -----------------------------------------------------------------------------------------
module "frontend_container_registry" {
  source               = "./modules/ecr"
  force_delete         = true
  scan_on_push         = false
  image_tag_mutability = "IMMUTABLE"
  bash_command         = "bash ${path.cwd}/../src/frontend/artifact_push.sh frontend-td ${var.region} http://${module.carshub_backend_lb.lb_dns_name} ${module.carshub_media_cloudfront_distribution.domain_name}"
  name                 = "frontend-td"
}

module "backend_container_registry" {
  source               = "./modules/ecr"
  force_delete         = true
  scan_on_push         = false
  image_tag_mutability = "IMMUTABLE"
  bash_command         = "bash ${path.cwd}/../src/backend/api/artifact_push.sh backend-td ${var.region}"
  name                 = "backend-td"
}

# ---------------------------------------------------------------------
# DB configuration
# ---------------------------------------------------------------------
module "db" {
  source                          = "./modules/rds"
  db_name                         = "db"
  allocated_storage               = 20
  engine                          = "mysql"
  engine_version                  = "8.0"
  instance_class                  = "db.t3.medium"
  multi_az                        = true
  username                        = tostring(data.vault_generic_secret.rds.data["username"])
  password                        = tostring(data.vault_generic_secret.rds.data["password"])
  subnet_group_name               = "rds_subnet_group"
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  backup_retention_period         = 35
  backup_window                   = "03:00-06:00"
  subnet_group_ids = [
    module.public_subnets.subnets[0].id,
    module.public_subnets.subnets[1].id,
    module.public_subnets.subnets[2].id
  ]
  vpc_security_group_ids                = [module.rds_security_group.id]
  publicly_accessible                   = false
  deletion_protection                   = false
  skip_final_snapshot                   = true
  max_allocated_storage                 = 40
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  parameter_group_name                  = "db-pg"
  parameter_group_family                = "mysql8.0"
  parameters = [
    {
      name  = "max_connections"
      value = "1000"
    },
    {
      name  = "innodb_buffer_pool_size"
      value = "{DBInstanceClassMemory*3/4}"
    },
    {
      name  = "slow_query_log"
      value = "1"
    }
  ]
}

# -----------------------------------------------------------------------------------------
# Load Balancer Configuration
# -----------------------------------------------------------------------------------------
module "frontend_lb" {
  source                     = "./modules/load-balancer"
  lb_name                    = "frontend-lb"
  lb_is_internal             = false
  lb_ip_address_type         = "ipv4"
  load_balancer_type         = "application"
  drop_invalid_header_fields = true
  enable_deletion_protection = false
  security_groups            = [module.carshub_frontend_lb_sg.id]
  subnets                    = module.carshub_public_subnets.subnets[*].id
  target_groups = [
    {
      target_group_name      = "frontend-tg"
      target_port            = 3000
      target_ip_address_type = "ipv4"
      target_protocol        = "HTTP"
      target_type            = "ip"
      target_vpc_id          = module.vpc.vpc_id

      health_check_interval            = 30
      health_check_path                = "/auth/signin"
      health_check_enabled             = true
      health_check_protocol            = "HTTP"
      health_check_timeout             = 5
      health_check_healthy_threshold   = 3
      health_check_unhealthy_threshold = 3
      health_check_port                = 3000

    }
  ]
  listeners = [
    {
      listener_port     = 80
      listener_protocol = "HTTP"
      certificate_arn   = null
      default_actions = [
        {
          type             = "forward"
          target_group_arn = module.carshub_frontend_lb.target_groups[0].arn
        }
      ]
    }
  ]
}

module "backend_lb" {
  source                     = "./modules/load-balancer"
  lb_name                    = "backend-lb"
  lb_is_internal             = false
  lb_ip_address_type         = "ipv4"
  load_balancer_type         = "application"
  drop_invalid_header_fields = true
  enable_deletion_protection = false
  security_groups            = [module.carshub_frontend_lb_sg.id]
  subnets                    = module.carshub_public_subnets.subnets[*].id
  target_groups = [
    {
      target_group_name      = "backend-tg"
      target_port            = 3000
      target_ip_address_type = "ipv4"
      target_protocol        = "HTTP"
      target_type            = "ip"
      target_vpc_id          = module.vpc.vpc_id

      health_check_interval            = 30
      health_check_path                = "/auth/signin"
      health_check_enabled             = true
      health_check_protocol            = "HTTP"
      health_check_timeout             = 5
      health_check_healthy_threshold   = 3
      health_check_unhealthy_threshold = 3
      health_check_port                = 3000

    }
  ]
  listeners = [
    {
      listener_port     = 80
      listener_protocol = "HTTP"
      certificate_arn   = null
      default_actions = [
        {
          type             = "forward"
          target_group_arn = module.carshub_frontend_lb.target_groups[0].arn
        }
      ]
    }
  ]
}

# ---------------------------------------------------------------------
# ECS configuration
# ---------------------------------------------------------------------

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-cluster-"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

module "frontend_ecs" {
  source                                   = "./modules/ecs"
  task_definition_family                   = "frontend-task-definition"
  task_definition_requires_compatibilities = ["FARGATE"]
  task_definition_cpu                      = 2048
  task_definition_memory                   = 4096
  task_definition_execution_role_arn       = module.ecs_task_execution_role.arn
  task_definition_task_role_arn            = module.ecs_task_execution_role.arn
  task_definition_network_mode             = "awsvpc"
  task_definition_cpu_architecture         = "X86_64"
  task_definition_operating_system_family  = "LINUX"
  task_definition_container_definitions = jsonencode(
    [
      {
        "name" : "frontend-td",
        "image" : "${module.frontend_container_registry.repository_url}:latest",
        "cpu" : 1024,
        "memory" : 2048,
        "placementStrategy" : [
          { "type" : "spread", "field" : "attribute:ecs.availability-zone" }
        ]
        "essential" : true,
        "healthCheck" : {
          "command" : ["CMD-SHELL", "curl -f http://localhost:3000/auth/signin || exit 1"],
          "interval" : 30,
          "timeout" : 5,
          "retries" : 3,
          "startPeriod" : 60
        },
        "ulimits" : [
          {
            "name" : "nofile",
            "softLimit" : 65536,
            "hardLimit" : 65536
          }
        ]
        "portMappings" : [
          {
            "containerPort" : 3000,
            "hostPort" : 3000,
            "name" : "frontend-td"
          }
        ],
        "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-group" : "${module.frontend_ecs_log_group.name}",
            "awslogs-region" : "${var.region}",
            "awslogs-stream-prefix" : "ecs"
          }
        },
        environment = [
          {
            name  = "BASE_URL"
            value = "${module.backend_lb.lb_dns_name}"
          }
        ]
      },
      {
        "name" : "xray-daemon",
        "image" : "amazon/aws-xray-daemon",
        "cpu" : 32,
        "memoryReservation" : 256,
        "portMappings" : [
          {
            "containerPort" : 2000,
            "protocol" : "udp"
          }
        ]
      },
  ])

  service_name                = "frontend-ecs-service"
  service_cluster             = aws_ecs_cluster.ecs_cluster.id
  service_launch_type         = "FARGATE"
  service_scheduling_strategy = "REPLICA"
  service_desired_count       = 2
  deployment_controller_type  = "ECS"
  load_balancer_config = [{
    container_name   = "frontend-td"
    container_port   = 3000
    target_group_arn = module.frontend_lb.target_groups[0].arn
  }]
  security_groups = [module.ecs_frontend_sg.id]
  subnets = [
    module.private_subnets.subnets[0].id,
    module.private_subnets.subnets[1].id,
    module.private_subnets.subnets[2].id
  ]
  assign_public_ip = false
}

module "backend_ecs" {
  source                                   = "./modules/ecs"
  task_definition_family                   = "backend-task-definition"
  task_definition_requires_compatibilities = ["FARGATE"]
  task_definition_cpu                      = 2048
  task_definition_memory                   = 4096
  task_definition_execution_role_arn       = module.ecs_task_execution_role.arn
  task_definition_task_role_arn            = module.ecs_task_execution_role.arn
  task_definition_network_mode             = "awsvpc"
  task_definition_cpu_architecture         = "X86_64"
  task_definition_operating_system_family  = "LINUX"
  task_definition_container_definitions = jsonencode(
    [
      {
        "name" : "backend-td",
        "image" : "${module.backend_container_registry.repository_url}:latest",
        "cpu" : 1024,
        "memory" : 2048,
        "placementStrategy" : [
          { "type" : "spread", "field" : "attribute:ecs.availability-zone" }
        ]
        "essential" : true,
        "secrets" : [
          {
            "name" : "UN",
            "valueFrom" : "${module.db_credentials.arn}:username::"
          },
          {
            "name" : "CREDS",
            "valueFrom" : "${module.db_credentials.arn}:password::"
          }
        ],
        "healthCheck" : {
          "command" : ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"],
          "interval" : 30,
          "timeout" : 5,
          "retries" : 3,
          "startPeriod" : 60
        },
        "ulimits" : [
          {
            "name" : "nofile",
            "softLimit" : 65536,
            "hardLimit" : 65536
          }
        ]
        "portMappings" : [
          {
            "containerPort" : 80,
            "hostPort" : 80,
            "name" : "backend-td"
          }
        ],
        "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-group" : "${module.backend_ecs_log_group.name}",
            "awslogs-region" : "${var.region}",
            "awslogs-stream-prefix" : "ecs"
          }
        },
        environment = [
          {
            name  = "DB_PATH"
            value = "${tostring(split(":", module.db.endpoint)[0])}"
          },
          {
            name  = "DB_NAME"
            value = "${module.db.name}"
          }
        ]
      },
      {
        "name" : "xray-daemon",
        "image" : "amazon/aws-xray-daemon",
        "cpu" : 32,
        "memoryReservation" : 256,
        "portMappings" : [
          {
            "containerPort" : 2000,
            "protocol" : "udp"
          }
        ]
      }
  ])

  service_name                = "backend-ecs-service"
  service_cluster             = aws_ecs_cluster.ecs_cluster.id
  service_launch_type         = "FARGATE"
  service_scheduling_strategy = "REPLICA"
  service_desired_count       = 2
  deployment_controller_type  = "ECS"
  load_balancer_config = [{
    container_name   = "backend-td"
    container_port   = 80
    target_group_arn = module.backend_lb.target_groups[0].arn
  }]
  security_groups = [module.ecs_backend_sg.id]
  subnets = [
    module.private_subnets.subnets[0].id,
    module.private_subnets.subnets[1].id,
    module.private_subnets.subnets[2].id
  ]
  assign_public_ip = false
}

# ---------------------------------------------------------------------
# Bedrock Configuration
# ---------------------------------------------------------------------

data "aws_iam_policy_document" "texttosql_bedrock_agent_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["bedrock.amazonaws.com"]
      type        = "Service"
    }
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "aws:SourceAccount"
    }
    condition {
      test     = "ArnLike"
      values   = ["arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:agent/*"]
      variable = "AWS:SourceArn"
    }
  }
}

data "aws_iam_policy_document" "texttosql_bedrock_agent_permissions" {
  statement {
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}::foundation-model/anthropic.claude-v2",
    ]
  }
}

resource "aws_iam_role" "texttosql_bedrock_agent_role" {
  assume_role_policy = data.aws_iam_policy_document.texttosql_bedrock_agent_trust.json
  name_prefix        = "AmazonBedrockExecutionRoleForAgents_"
}

resource "aws_iam_role_policy" "texttosql_bedrock_agent_role_policy" {
  policy = data.aws_iam_policy_document.texttosql_bedrock_agent_permissions.json
  role   = aws_iam_role.texttosql_bedrock_agent_role.id
}

resource "aws_bedrockagent_agent" "texttosql_bedrock_agent" {
  agent_name                  = "texttosql-bedrock-agent"
  agent_resource_role_arn     = aws_iam_role.texttosql_bedrock_agent_role.arn
  idle_session_ttl_in_seconds = 500
  foundation_model            = "anthropic.claude-v4"
}

resource "aws_bedrockagent_knowledge_base" "texttosql_bedrock_agent_knowledge_base" {
  name     = "texttosql-bedrock-agent-knowledge-base"
  role_arn = aws_iam_role.texttosql_bedrock_agent_role.arn
  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:us-west-2::foundation-model/amazon.titan-embed-text-v2:0"
    }
    type = "VECTOR"
  }
  storage_configuration {
    type = "PINECONE"
    pinecone_configuration {
      connection_string      = ""
      credentials_secret_arn = ""
      namespace              = ""
      field_mapping {
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "texttosql_bedrock_agent_data_source" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.texttosql_bedrock_agent_knowledge_base.id
  name              = "texttosql-bedrock-agent-data-source"
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = "${module.bedrock_knowledge_base_data_source.arn}"
    }
  }
}

resource "aws_bedrockagent_agent_knowledge_base_association" "texttosql_bedrock_agent_knowledge_base_association" {
  agent_id             = aws_bedrockagent_agent.texttosql_bedrock_agent.agent_id
  description          = "texttosql-bedrock-agent-knowledge-base-association"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.texttosql_bedrock_agent_knowledge_base.id
  knowledge_base_state = "ENABLED"
}