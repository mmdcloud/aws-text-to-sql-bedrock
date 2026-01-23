data "aws_caller_identity" "current" {}

resource "random_id" "id" {
  byte_length = 8
}

data "aws_partition" "current" {}

data "aws_elb_service_account" "main" {}

data "aws_region" "current" {}

# ---------------------------------------------------------------------
# Registering vault provider
# ---------------------------------------------------------------------
data "vault_generic_secret" "rds" {
  path = "secret/rds"
}

data "vault_generic_secret" "pinecone" {
  path = "secret/pinecone"
}

# ---------------------------------------------------------------------
# VPC Configuration
# ---------------------------------------------------------------------
module "vpc" {
  source                  = "./modules/vpc"
  vpc_name                = "vpc"
  vpc_cidr                = "10.0.0.0/16"
  azs                     = var.azs
  public_subnets          = var.public_subnets
  private_subnets         = var.private_subnets
  database_subnets        = var.database_subnets
  enable_dns_hostnames    = true
  enable_dns_support      = true
  create_igw              = true
  map_public_ip_on_launch = true
  enable_nat_gateway      = true
  single_nat_gateway      = false
  one_nat_gateway_per_az  = true
  tags = {
    Project = "text-to-sql"
  }
}

module "frontend_lb_sg" {
  source = "./modules/security-groups"
  name   = "frontend-lb-sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      description     = "HTTP Traffic"
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description     = "HTTPS Traffic"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    }
  ]
  egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  tags = {
    Name = "frontend-lb-sg"
  }
}

module "backend_lb_sg" {
  source = "./modules/security-groups"
  name   = "backend-lb-sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      description     = "HTTP Traffic"
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = []
      security_groups = [module.ecs_frontend_sg.id]
    },
    {
      description     = "HTTPS Traffic"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = []
      security_groups = [module.ecs_frontend_sg.id]
    }
  ]
  egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  tags = {
    Name = "backend-lb-sg"
  }
}

module "ecs_frontend_sg" {
  source = "./modules/security-groups"
  name   = "ecs-frontend-sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      from_port       = 3000
      to_port         = 3000
      protocol        = "tcp"
      cidr_blocks     = []
      security_groups = [module.frontend_lb_sg.id]
    }
  ]
  egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  tags = {
    Name = "ecs-frontend-sg"
  }
}

module "ecs_backend_sg" {
  source = "./modules/security-groups"
  name   = "ecs-backend-sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = []
      security_groups = [module.backend_lb_sg.id]
    }
  ]
  egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  tags = {
    Name = "ecs-backend-sg"
  }
}

module "rds_sg" {
  source = "./modules/security-groups"
  name   = "rds-sg"
  vpc_id = module.vpc.vpc_id
  ingress_rules = [
    {
      from_port       = 3306
      to_port         = 3306
      protocol        = "tcp"
      cidr_blocks     = []
      security_groups = [module.ecs_backend_sg.id]
    }
  ]
  egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  tags = {
    Name = "rds-sg"
  }
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
      callback_urls                        = ["http://${module.frontend_lb.dns_name}/callback"]
      logout_urls                          = ["http://${module.frontend_lb.dns_name}/logout"]
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

module "pinecone_api_key" {
  source                  = "./modules/secrets-manager"
  name                    = "pinecone_api_key"
  description             = "pinecone_api_key"
  recovery_window_in_days = 0
  secret_string = jsonencode({
    api_key = tostring(data.vault_generic_secret.pinecone.data["api_key"])
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

module "frontend_lb_logs" {
  source      = "./modules/s3"
  bucket_name = "frontend-lb-logs"
  objects     = []
  bucket_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::frontend-lb-logs-${random_id.id.hex}/*"
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::frontend-lb-logs-${random_id.id.hex}"
      },
      {
        Sid    = "AWSELBAccountWrite"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_elb_service_account.main.id}:root"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::frontend-lb-logs-${random_id.id.hex}/*"
      }
    ]
  })
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

# module "backend_lb_logs" {
#   source      = "./modules/s3"
#   bucket_name = "backend-lb-logs"
#   objects     = []
#   bucket_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AWSLogDeliveryWrite"
#         Effect = "Allow"
#         Principal = {
#           Service = "logging.s3.amazonaws.com"
#         }
#         Action   = "s3:PutObject"
#         Resource = "arn:aws:s3:::backend-lb-logs-${random.id.hex}/*"
#       },
#       {
#         Sid    = "AWSLogDeliveryAclCheck"
#         Effect = "Allow"
#         Principal = {
#           Service = "logging.s3.amazonaws.com"
#         }
#         Action   = "s3:GetBucketAcl"
#         Resource = "arn:aws:s3:::backend-lb-logs-${random.id.hex}"
#       },
#       {
#         Sid    = "AWSELBAccountWrite"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::${data.aws_elb_service_account.main.id}:root"
#         }
#         Action   = "s3:PutObject"
#         Resource = "arn:aws:s3:::backend-lb-logs-${random.id.hex}/*"
#       }
#     ]
#   })
#   cors = [
#     {
#       allowed_headers = ["*"]
#       allowed_methods = ["GET"]
#       allowed_origins = ["*"]
#       max_age_seconds = 3000
#     },
#     {
#       allowed_headers = ["*"]
#       allowed_methods = ["PUT"]
#       allowed_origins = ["*"]
#       max_age_seconds = 3000
#     }
#   ]
#   versioning_enabled = "Enabled"
#   force_destroy      = true
# }

# -----------------------------------------------------------------------------------------
# ECR Module
# -----------------------------------------------------------------------------------------
module "frontend_container_registry" {
  source               = "./modules/ecr"
  force_delete         = true
  scan_on_push         = false
  image_tag_mutability = "IMMUTABLE"
  bash_command         = "bash ${path.cwd}/../src/frontend/artifact_push.sh frontend-td ${var.region}"
  name                 = "frontend-td"
  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# module "backend_container_registry" {
#   source               = "./modules/ecr"
#   force_delete         = true
#   scan_on_push         = false
#   image_tag_mutability = "IMMUTABLE"
#   bash_command         = "bash ${path.cwd}/../src/backend/artifact_push.sh backend-td ${var.region}"
#   name                 = "backend-td"
#   lifecycle_policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1
#         description  = "Keep last 10 images"
#         selection = {
#           tagStatus     = "tagged"
#           tagPrefixList = ["v"]
#           countType     = "imageCountMoreThan"
#           countNumber   = 10
#         }
#         action = {
#           type = "expire"
#         }
#       },
#       {
#         rulePriority = 2
#         description  = "Delete untagged images older than 7 days"
#         selection = {
#           tagStatus   = "untagged"
#           countType   = "sinceImagePushed"
#           countUnit   = "days"
#           countNumber = 7
#         }
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
# }

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
  backup_window                   = "03:00-04:00" # 1 hour backup
  maintenance_window              = "Mon:04:30-Mon:05:30"
  subnet_group_ids = [
    module.vpc.database_subnets[0],
    module.vpc.database_subnets[1],
    module.vpc.database_subnets[2]
  ]
  vpc_security_group_ids                = [module.rds_sg.id]
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
    }
    # {
    #   name  = "innodb_buffer_pool_size"
    #   value = "{DBInstanceClassMemory*3/4}"
    # },
    # {
    #   name  = "slow_query_log"
    #   value = "1"
    # }
  ]
}

# -----------------------------------------------------------------------------------------
# Load Balancer Configuration
# -----------------------------------------------------------------------------------------
module "frontend_lb" {
  source                     = "terraform-aws-modules/alb/aws"
  name                       = "frontend-lb"
  load_balancer_type         = "application"
  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.public_subnets
  enable_deletion_protection = false
  drop_invalid_header_fields = true
  ip_address_type            = "ipv4"
  internal                   = false
  security_groups = [
    module.frontend_lb_sg.id
  ]
  access_logs = {
    bucket = "${module.frontend_lb_logs.bucket}"
  }
  listeners = {
    frontend_lb_http_listener = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "frontend_lb_target_group"
      }
    }
  }
  target_groups = {
    frontend_lb_target_group = {
      backend_protocol = "HTTP"
      backend_port     = 3000
      target_type      = "ip"
      health_check = {
        enabled             = true
        healthy_threshold   = 3
        interval            = 30
        path                = "/auth/signin"
        port                = 3000
        protocol            = "HTTP"
        unhealthy_threshold = 3
      }
      create_attachment = false
    }
  }
  tags = {
    Project = "text-to-sql-frontend-lb"
  }
}

# module "backend_lb" {
#   source                     = "terraform-aws-modules/alb/aws"
#   name                       = "backend-lb"
#   load_balancer_type         = "application"
#   vpc_id                     = module.vpc.vpc_id
#   subnets                    = module.vpc.private_subnets
#   enable_deletion_protection = false
#   drop_invalid_header_fields = true
#   ip_address_type            = "ipv4"
#   internal                   = true
#   security_groups = [
#     module.backend_lb_sg.id
#   ]
#   access_logs = {
#     bucket = "${module.backend_lb_logs.bucket}"
#   }
#   listeners = {
#     backend_lb_http_listener = {
#       port     = 80
#       protocol = "HTTP"
#       forward = {
#         target_group_key = "backend_lb_target_group"
#       }
#     }
#   }
#   target_groups = {
#     backend_lb_target_group = {
#       backend_protocol = "HTTP"
#       backend_port     = 80
#       target_type      = "ip"
#       health_check = {
#         enabled             = true
#         healthy_threshold   = 3
#         interval            = 30
#         path                = "/"
#         port                = 80
#         protocol            = "HTTP"
#         unhealthy_threshold = 3
#       }
#       create_attachment = false
#     }
#   }
#   tags = {
#     Project = "text-to-sql-backend-lb"
#   }
# }

# ---------------------------------------------------------------------
# ECS configuration
# ---------------------------------------------------------------------
module "ecs_task_execution_role" {
  source             = "./modules/iam"
  role_name          = "ecs-task-execution-role"
  role_description   = "IAM role for ECS task execution"
  policy_name        = "ecs-task-execution-policy"
  policy_description = "IAM policy for ECS task execution"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "ecs-tasks.amazonaws.com"
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
                  "s3:PutObject"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },
            {
              "Effect": "Allow",
              "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
              ],
              "Resource": [
                "${module.db_credentials.arn}",
                "${module.pinecone_api_key.arn}"
              ]
            },
            {
                "Action": [
                  "bedrock:InvokeAgent",
                  "bedrock:InvokeModel"
                ],
                "Resource": "*",
                "Effect": "Allow"
            },
        ]
    }
    EOF
}

# ECR-ECS policy attachment 
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = module.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

module "frontend_ecs_log_group" {
  source            = "./modules/cloudwatch/cloudwatch-log-group"
  log_group_name    = "/aws/ecs/frontend-ecs"
  retention_in_days = 90
}

module "backend_ecs_log_group" {
  source            = "./modules/cloudwatch/cloudwatch-log-group"
  log_group_name    = "/aws/ecs/backend-ecs"
  retention_in_days = 90
}

module "ecs" {
  source       = "terraform-aws-modules/ecs/aws"
  cluster_name = "text-to-sql-cluster"
  default_capacity_provider_strategy = {
    FARGATE = {
      weight = 100
      base   = 1
    }
  }
  services = {
    ecs_frontend = {
      cpu                    = 2048
      memory                 = 4096
      task_exec_iam_role_arn = module.ecs_task_execution_role.arn
      iam_role_arn           = module.ecs_task_execution_role.arn
      desired_count          = 2
      assign_public_ip       = false
      deployment_controller = {
        type = "ECS"
      }
      network_mode = "awsvpc"
      runtime_platform = {
        cpu_architecture        = "X86_64"
        operating_system_family = "LINUX"
      }
      launch_type              = "FARGATE"
      scheduling_strategy      = "REPLICA"
      requires_compatibilities = ["FARGATE"]
      container_definitions = {
        ecs_frontend = {
          cpu       = 1024
          memory    = 2048
          essential = true
          image     = "${module.frontend_container_registry.repository_url}:latest"
          healthCheck = {
            command = ["CMD-SHELL", "curl -f http://localhost:3000/auth/signin || exit 1"]
          }
          ulimits = [
            {
              name      = "nofile"
              softLimit = 65536
              hardLimit = 65536
            }
          ]
          portMappings = [
            {
              name          = "ecs_frontend"
              containerPort = 3000
              hostPort      = 3000
              protocol      = "tcp"
            }
          ]
          environment = [
            # {
            #   name  = "BASE_URL"
            #   value = "${module.backend_lb.dns_name}"
            # }
          ]
          capacity_provider_strategy = {
            ASG = {
              base              = 20
              capacity_provider = "ASG"
              weight            = 50
            }
          }
          readonlyRootFilesystem    = false
          enable_cloudwatch_logging = false
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = module.frontend_ecs_log_group.name
              awslogs-region        = var.region
              awslogs-stream-prefix = "frontend"
            }
          }
          memoryReservation = 100
          restartPolicy = {
            enabled              = true
            ignoredExitCodes     = [1]
            restartAttemptPeriod = 60
          }
        }
      }
      load_balancer = {
        service = {
          target_group_arn = module.frontend_lb.target_groups["frontend_lb_target_group"].arn
          container_name   = "ecs_frontend"
          container_port   = 3000
        }
      }
      subnet_ids                    = module.vpc.private_subnets
      vpc_id                        = module.vpc.vpc_id
      security_group_ids            = [module.ecs_frontend_sg.id]
      availability_zone_rebalancing = "ENABLED"
    }

    # ecs_backend = {
    #   cpu                    = 2048
    #   memory                 = 4096
    #   task_exec_iam_role_arn = module.ecs_task_execution_role.arn
    #   iam_role_arn           = module.ecs_task_execution_role.arn
    #   desired_count          = 2
    #   assign_public_ip       = false
    #   deployment_controller = {
    #     type = "ECS"
    #   }
    #   network_mode = "awsvpc"
    #   runtime_platform = {
    #     cpu_architecture        = "X86_64"
    #     operating_system_family = "LINUX"
    #   }
    #   launch_type              = "FARGATE"
    #   scheduling_strategy      = "REPLICA"
    #   requires_compatibilities = ["FARGATE"]
    #   container_definitions = {
    #     ecs_backend = {
    #       cpu       = 1024
    #       memory    = 2048
    #       essential = true
    #       image     = "${module.backend_container_registry.repository_url}:latest"
    #       healthCheck = {
    #         command = ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"]
    #       }
    #       ulimits = [
    #         {
    #           name      = "nofile"
    #           softLimit = 65536
    #           hardLimit = 65536
    #         }
    #       ]
    #       environment = [
    #         {
    #           name  = "DB_PATH"
    #           value = "${tostring(split(":", module.db.endpoint)[0])}"
    #         },
    #         {
    #           name  = "DB_NAME"
    #           value = "${module.db.name}"
    #         }
    #       ]
    #       portMappings = [
    #         {
    #           name          = "ecs_backend"
    #           containerPort = 80
    #           hostPort      = 80
    #           protocol      = "tcp"
    #         }
    #       ]
    #       readOnlyRootFilesystem    = false
    #       enable_cloudwatch_logging = false
    #       logConfiguration = {
    #         logDriver = "awslogs"
    #         options = {
    #           awslogs-group         = module.backend_ecs_log_group.name
    #           awslogs-region        = var.region
    #           awslogs-stream-prefix = "backend"
    #         }
    #       }
    #       memoryReservation = 100
    #       restartPolicy = {
    #         enabled              = true
    #         ignoredExitCodes     = [1]
    #         restartAttemptPeriod = 60
    #       }
    #     }
    #   }
    #   load_balancer = {
    #     service = {
    #       target_group_arn = module.backend_lb.target_groups["backend_lb_target_group"].arn
    #       container_name   = "ecs_backend"
    #       container_port   = 80
    #     }
    #   }
    #   subnet_ids                    = module.vpc.private_subnets
    #   vpc_id                        = module.vpc.vpc_id
    #   security_group_ids            = [module.ecs_backend_sg.id]
    #   availability_zone_rebalancing = "ENABLED"
    # }
  }
}

module "frontend_app_autoscaling_policy" {
  source             = "./modules/autoscaling"
  min_capacity       = 2
  max_capacity       = 10
  resource_id        = "service/${module.ecs.cluster_name}/${module.ecs.services["ecs_frontend"].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  policies = [
    {
      name        = "worker-scale-up"
      policy_type = "TargetTrackingScaling"
      step_scaling_policy_configuration = {
        adjustment_type         = "ChangeInCapacity"
        cooldown                = 60
        metric_aggregation_type = "Average"
        # min_adjustment_magnitude = 1
        step_adjustment = [
          {
            metric_interval_lower_bound = 0
            metric_interval_upper_bound = 20
            scaling_adjustment          = 1
          },
          {
            metric_interval_lower_bound = 20
            scaling_adjustment          = 2
          }
        ]
      }
    }
  ]
}

# module "backend_app_autoscaling_policy" {
#   source             = "./modules/autoscaling"
#   min_capacity       = 2
#   max_capacity       = 10
#   resource_id        = "service/${module.ecs.cluster_name}/${module.ecs.services["ecs_backend"].name}"
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
#   policies = [
#     {
#       name        = "worker-scale-up"
#       policy_type = "TargetTrackingScaling"
#       step_scaling_policy_configuration = {
#         adjustment_type         = "ChangeInCapacity"
#         cooldown                = 60
#         metric_aggregation_type = "Average"
#         # min_adjustment_magnitude = 1
#         step_adjustment = [
#           {
#             metric_interval_lower_bound = 0
#             metric_interval_upper_bound = 20
#             scaling_adjustment          = 1
#           },
#           {
#             metric_interval_lower_bound = 20
#             scaling_adjustment          = 2
#           }
#         ]
#       }
#     }
#   ]
# }

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
      "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}::foundation-model/anthropic.claude-opus-4-5-20251101-v1:0",
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

module "bedrock_agent" {
  source = "./modules/bedrock/agent"

  agent_name                  = "texttosql-agent"
  description                 = "AI agent for safe text-to-SQL conversion with security guardrails"
  foundation_model            = "anthropic.claude-opus-4-5-20251101-v1:0"
  agent_resource_role_arn     = aws_iam_role.texttosql_bedrock_agent_role.arn
  idle_session_ttl_in_seconds = 500

  # Enhanced Instructions for SQL Safety
  instruction = <<-EOT
    You are a specialized SQL generation assistant with strict security protocols. Your role is to convert natural language queries into safe, read-only SQL statements.

    CRITICAL SECURITY RULES:
    1. ONLY generate SELECT statements - never DROP, DELETE, UPDATE, INSERT, TRUNCATE, ALTER, or any DDL/DML operations
    2. Always use parameterized queries or proper escaping to prevent SQL injection
    3. Never expose sensitive data like passwords, tokens, SSNs, credit cards, or PII in WHERE clauses or results
    4. Limit result sets using TOP, LIMIT, or FETCH FIRST clauses (default max 1000 rows)
    5. Always validate table and column names against the schema in the knowledge base
    6. Never use wildcards (*) without explicit column specification for sensitive tables
    7. Avoid joins that could create Cartesian products or excessive data exposure
    8. Never reference system tables, information_schema, or metadata tables directly
    9. Include appropriate WHERE clauses to filter data contextually
    10. Use table aliases and proper formatting for readability

    QUERY VALIDATION:
    - Before generating SQL, verify the requested tables and columns exist in the schema
    - Check if the query might expose sensitive information
    - Ensure the query has proper filtering to avoid full table scans
    - Validate that aggregations and groupings are logically correct
    - Confirm the query aligns with the user's apparent intent

    OUTPUT FORMAT:
    - Provide the SQL query with clear formatting
    - Include a brief explanation of what the query does
    - List any assumptions made
    - Warn if the query might return large result sets
    - Suggest optimizations if applicable

    ERROR HANDLING:
    - If a request seems malicious or dangerous, politely decline and explain why
    - If insufficient information is provided, ask clarifying questions
    - If a table or column doesn't exist, suggest alternatives from the schema

    You have access to a knowledge base containing:
    - Database schemas with table definitions
    - Column descriptions and data types
    - Relationship diagrams and constraints
    - Best practices and query examples
    - Business logic and data governance rules

    Always prioritize data security and user privacy over query flexibility.
  EOT

  # Guardrail Configuration
  guardrail_identifier = module.bedrock_guardrail.guardrail_id
  guardrail_version    = module.bedrock_guardrail.guardrail_version

  # Knowledge Base Association
  knowledge_bases = [
    {
      knowledge_base_id    = module.bedrock_knowledge_base.knowledge_base_id
      description          = "Database schemas, documentation, and SQL best practices"
      knowledge_base_state = "ENABLED"
    }
  ]

  # Action Groups - Could add SQL validation functions here
  action_groups = []

  # Prompt Override Configuration for enhanced SQL safety
  prompt_override_configuration = {
    prompt_configurations = [
      {
        prompt_type          = "PRE_PROCESSING"
        prompt_creation_mode = "OVERRIDDEN"
        prompt_state         = "ENABLED"
        base_prompt_template = <<-EOT
          Analyze the user's request carefully for any malicious intent or dangerous SQL operations.
          Check for:
          - SQL injection patterns
          - Attempts to access system tables
          - Destructive operations (DROP, DELETE, TRUNCATE)
          - Privilege escalation attempts
          - Credential exposure risks
          
          If any security concerns are detected, reject the request politely.
          Otherwise, proceed to generate a safe, read-only SQL query.
        EOT
        inference_configuration = [{
          temperature    = 0.0
          top_p          = 0.9
          top_k          = 250
          max_length     = 2048
          stop_sequences = ["</sql>", "COMMIT;", "ROLLBACK;"]
        }]
      },
      {
        prompt_type          = "ORCHESTRATION"
        prompt_creation_mode = "OVERRIDDEN"
        prompt_state         = "ENABLED"
        base_prompt_template = <<-EOT
          Generate a SQL query following these rules:
          1. Use only SELECT statements
          2. Include appropriate WHERE clauses for filtering
          3. Limit results to prevent excessive data exposure (max 1000 rows)
          4. Use proper table and column aliases
          5. Validate against the schema in the knowledge base
          6. Format the query for readability
          7. Add comments explaining complex logic
          
          Schema validation is mandatory before query generation.
        EOT
        inference_configuration = [{
          temperature    = 0.1
          top_p          = 0.95
          top_k          = 250
          max_length     = 4096
          stop_sequences = ["</answer>"]
          }
        ]
      },
      {
        prompt_type          = "POST_PROCESSING"
        prompt_creation_mode = "OVERRIDDEN"
        prompt_state         = "ENABLED"
        base_prompt_template = <<-EOT
          Review the generated SQL query for:
          - Security vulnerabilities
          - Performance implications
          - Data exposure risks
          - Compliance with read-only constraints
          
          Provide the query with:
          - Clear explanation
          - Expected result structure
          - Any warnings or recommendations
          - Performance considerations
        EOT
        inference_configuration = [{
          temperature    = 0.0
          top_p          = 0.9
          top_k          = 250
          max_length     = 2048
          stop_sequences = []
        }]
      }
    ]
  }

  tags = {
    Project   = "text-to-sql"
    ManagedBy = "Terraform"
    Security  = "Guardrails-Enabled"
  }
}

module "bedrock_knowledge_base" {
  source = "./modules/bedrock/knowledge-base"

  name        = "texttosql-knowledge-base"
  description = "Knowledge base for TextToSQL application"
  role_arn    = aws_iam_role.texttosql_bedrock_agent_role.arn

  # Vector Configuration
  embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0"

  # Storage Configuration
  storage_type = "PINECONE"

  pinecone_config = {
    connection_string      = "https://texttosql-otehowi.svc.aped-4627-b74a.pinecone.io"
    credentials_secret_arn = module.pinecone_api_key.arn
    namespace              = "__default__"
    text_field             = "AMAZON_BEDROCK_TEXT_CHUNK"
    metadata_field         = "AMAZON_BEDROCK_METADATA"
  }

  # Data Source Configuration
  data_sources = [
    {
      name               = "s3-documentation"
      description        = "S3 bucket containing documentation"
      type               = "S3"
      bucket_arn         = module.bedrock_knowledge_base_data_source.arn
      inclusion_prefixes = []
      exclusion_prefixes = []
    }
  ]

  tags = {
    Project   = "text-to-sql"
    ManagedBy = "Terraform"
  }
}

module "bedrock_guardrail" {
  source = "./modules/bedrock/guardrail"

  name                      = "texttosql-guardrail"
  description               = "Guardrail for TextToSQL Bedrock Agent - Ensures safe SQL generation and prevents data exposure"
  blocked_input_messaging   = "Your query cannot be processed. Please ensure it relates to valid database operations without sensitive commands."
  blocked_outputs_messaging = "The generated SQL was blocked due to safety policies. Please rephrase your question."

  # Content Policy - Focused on SQL injection and malicious patterns
  content_filters = [
    {
      type            = "HATE"
      input_strength  = "LOW" # Less relevant for SQL queries
      output_strength = "MEDIUM"
    },
    {
      type            = "VIOLENCE"
      input_strength  = "LOW" # Less relevant for SQL queries
      output_strength = "LOW"
    },
    {
      type            = "SEXUAL"
      input_strength  = "MEDIUM" # Prevent inappropriate table/column names
      output_strength = "MEDIUM"
    },
    {
      type            = "MISCONDUCT"
      input_strength  = "HIGH" # Block attempts to manipulate system
      output_strength = "HIGH"
    }
  ]

  content_tier = "STANDARD"

  # PII Configuration - Critical for database security
  pii_entities = [
    {
      type           = "NAME"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    },
    {
      type           = "EMAIL"
      action         = "BLOCK"
      input_action   = "ANONYMIZE"
      output_action  = "BLOCK" # Don't expose emails in SQL
      input_enabled  = true
      output_enabled = true
    },
    {
      type           = "PHONE"
      action         = "BLOCK"
      input_action   = "ANONYMIZE"
      output_action  = "BLOCK" # Don't expose phone numbers in SQL
      input_enabled  = true
      output_enabled = true
    },
    {
      type           = "ADDRESS"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    },
    {
      type           = "USERNAME"
      action         = "ANONYMIZE"
      input_action   = "ANONYMIZE"
      output_action  = "ANONYMIZE"
      input_enabled  = true
      output_enabled = true
    },
    {
      type           = "PASSWORD"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK" # Never allow passwords
      input_enabled  = true
      output_enabled = true
    },
    {
      type           = "DRIVER_ID"
      action         = "BLOCK"
      input_action   = "ANONYMIZE"
      output_action  = "BLOCK"
      input_enabled  = true
      output_enabled = true
    },
    {
      type           = "US_SOCIAL_SECURITY_NUMBER"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK"
      input_enabled  = true
      output_enabled = true
    },
    {
      type           = "CREDIT_DEBIT_CARD_NUMBER"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK"
      input_enabled  = true
      output_enabled = true
    }
  ]

  # Regex Patterns - SQL-specific dangerous patterns
  regex_patterns = [
    {
      name           = "sql_injection_union"
      description    = "Detects UNION-based SQL injection attempts"
      pattern        = "(?i)(union\\s+(all\\s+)?select|union\\s+distinct)"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK"
      input_enabled  = true
      output_enabled = false # Output is generated SQL, different validation
    },
    {
      name           = "sql_injection_comment"
      description    = "Detects SQL comment injection attempts"
      pattern        = "(?i)(--|#|/\\*|\\*/|;\\s*--)"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK"
      input_enabled  = true
      output_enabled = false
    },
    {
      name           = "dangerous_sql_commands"
      description    = "Blocks dangerous SQL commands in user input"
      pattern        = "(?i)\\b(drop\\s+table|drop\\s+database|truncate|delete\\s+from|exec|execute|xp_|sp_|grant|revoke|alter\\s+table|create\\s+user|drop\\s+user)\\b"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK" # Also prevent generation of dangerous SQL
      input_enabled  = true
      output_enabled = true
    },
    {
      name           = "sql_stacked_queries"
      description    = "Detects stacked query attempts"
      pattern        = ";\\s*(select|insert|update|delete|drop|create|alter)"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK"
      input_enabled  = true
      output_enabled = true
    },
    {
      name           = "ssn_pattern"
      description    = "Detects US Social Security Numbers"
      pattern        = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK"
      input_enabled  = true
      output_enabled = true
    },
    {
      name           = "credit_card_pattern"
      description    = "Detects credit card numbers"
      pattern        = "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK"
      input_enabled  = true
      output_enabled = true
    },
    {
      name           = "aws_access_key"
      description    = "Detects AWS access keys"
      pattern        = "(?i)(AKIA[0-9A-Z]{16})"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK"
      input_enabled  = true
      output_enabled = true
    },
    {
      name           = "database_credentials"
      description    = "Detects potential database connection strings"
      pattern        = "(?i)(password\\s*=|pwd\\s*=|passwd\\s*=|user\\s*id\\s*=)"
      action         = "BLOCK"
      input_action   = "BLOCK"
      output_action  = "BLOCK"
      input_enabled  = true
      output_enabled = true
    }
  ]

  # Topic Policy - SQL and Database specific denied topics
  denied_topics = [
    {
      name       = "destructive_operations"
      definition = "Requests to delete, drop, truncate, or permanently destroy database objects, tables, or data without proper authorization or context."
      examples = [
        "Delete all records from the users table",
        "Drop the customer database",
        "Truncate the orders table",
        "Remove all data from production"
      ]
    },
    {
      name       = "unauthorized_data_modification"
      definition = "Requests to insert, update, or modify data without proper context or authorization, especially in sensitive tables."
      examples = [
        "Update all user passwords",
        "Change the admin email to my email",
        "Insert myself as an administrator",
        "Modify salary information for all employees"
      ]
    },
    {
      name       = "schema_manipulation"
      definition = "Requests to alter database structure, create or drop tables, modify constraints, or change database architecture."
      examples = [
        "Create a new admin table",
        "Alter the users table to add a field",
        "Drop the foreign key constraint",
        "Modify the database schema"
      ]
    },
    {
      name       = "bulk_sensitive_data_export"
      definition = "Requests to export large amounts of sensitive personal information, credentials, or confidential business data."
      examples = [
        "Show me all user passwords",
        "Export all social security numbers",
        "List all credit card information",
        "Give me everyone's personal details"
      ]
    },
    {
      name       = "privilege_escalation"
      definition = "Requests to grant permissions, create users, modify roles, or escalate database privileges."
      examples = [
        "Grant admin privileges to this user",
        "Create a superuser account",
        "Give me all database permissions",
        "Add DBA role to my account"
      ]
    },
    {
      name       = "system_command_execution"
      definition = "Requests to execute system commands, stored procedures, or extended stored procedures that could compromise security."
      examples = [
        "Execute xp_cmdshell",
        "Run system commands via SQL",
        "Execute operating system commands",
        "Access file system through database"
      ]
    },
    {
      name       = "cross_database_access"
      definition = "Requests to access databases, schemas, or tables outside the intended scope or authorized context."
      examples = [
        "Show me data from all databases",
        "Access the admin database",
        "Query tables from other schemas",
        "Connect to production database"
      ]
    },
    {
      name       = "financial_advice"
      definition = "Requests for financial recommendations, investment advice, or monetary guidance beyond simple data queries."
      examples = [
        "Which stocks should I invest in based on our data?",
        "What's the best financial strategy?",
        "Should I buy or sell this asset?"
      ]
    },
    {
      name       = "medical_diagnosis"
      definition = "Requests for medical diagnosis or health advice that should come from licensed healthcare professionals."
      examples = [
        "Do I have a medical condition based on this data?",
        "What treatment should I get?",
        "Diagnose my symptoms"
      ]
    },
    {
      name       = "credential_exposure"
      definition = "Any request that could expose authentication credentials, API keys, tokens, or security secrets."
      examples = [
        "Show me the API keys table",
        "What are the stored credentials?",
        "List all authentication tokens",
        "Display user session secrets"
      ]
    }
  ]

  topic_tier = "CLASSIC"

  # Word Policy - SQL-specific dangerous keywords and profanity
  managed_word_lists = ["PROFANITY"]

  custom_blocked_words = [
    "xp_cmdshell",
    "xp_regread",
    "xp_regwrite",
    "sp_addextendedproc",
    "sp_oacreate",
    "xp_servicecontrol",
    "xp_subdirs",
    "xp_dirtree",
    "exec(@",
    "exec(",
    "execute(@",
    "execute(",
    "INFORMATION_SCHEMA.TABLES",
    "sysobjects",
    "syscolumns",
    "master..sysdatabases"
  ]

  tags = {
    Project   = "text-to-sql"
    ManagedBy = "Terraform"
    Purpose   = "SQL-Safety-Guardrails"
  }
}

# resource "aws_bedrockagent_agent" "texttosql_bedrock_agent" {
#   agent_name                  = "texttosql-bedrock-agent"
#   agent_resource_role_arn     = aws_iam_role.texttosql_bedrock_agent_role.arn
#   idle_session_ttl_in_seconds = 500
#   foundation_model            = "anthropic.claude-opus-4-5-20251101-v1:0"
#   guardrail_configuration = [{
#     guardrail_identifier = "${aws_bedrock_guardrail.texttosql_bedrock_agent_guardrail.guardrail_id}"
#     guardrail_version    = "${aws_bedrock_guardrail_version.guardrail_version.version}"
#   }]
# }

# resource "aws_bedrockagent_knowledge_base" "texttosql_bedrock_agent_knowledge_base" {
#   name     = "texttosql-bedrock-agent-knowledge-base"
#   role_arn = aws_iam_role.texttosql_bedrock_agent_role.arn
#   knowledge_base_configuration {
#     vector_knowledge_base_configuration {
#       embedding_model_arn = "arn:aws:bedrock:us-west-2::foundation-model/amazon.titan-embed-text-v2:0"
#     }
#     type = "VECTOR"
#   }
#   storage_configuration {
#     type = "PINECONE"
#     pinecone_configuration {
#       connection_string      = "https://texttosql-otehowi.svc.aped-4627-b74a.pinecone.io"
#       credentials_secret_arn = module.pinecone_api_key.arn
#       namespace              = "__default__"
#       field_mapping {
#         text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
#         metadata_field = "AMAZON_BEDROCK_METADATA"
#       }
#     }
#   }
# }

# resource "aws_bedrockagent_data_source" "texttosql_bedrock_agent_data_source" {
#   knowledge_base_id = aws_bedrockagent_knowledge_base.texttosql_bedrock_agent_knowledge_base.id
#   name              = "texttosql-bedrock-agent-data-source"
#   description       = "TextToSQL Bedrock Agent Data Source"
#   data_source_configuration {
#     type = "S3"
#     s3_configuration {
#       bucket_arn = module.bedrock_knowledge_base_data_source.arn
#     }
#   }
# }

# resource "aws_bedrockagent_agent_knowledge_base_association" "texttosql_bedrock_agent_knowledge_base_association" {
#   agent_id             = aws_bedrockagent_agent.texttosql_bedrock_agent.agent_id
#   description          = "texttosql-bedrock-agent-knowledge-base-association"
#   knowledge_base_id    = aws_bedrockagent_knowledge_base.texttosql_bedrock_agent_knowledge_base.id
#   knowledge_base_state = "ENABLED"
# }

# resource "aws_bedrock_guardrail" "texttosql_bedrock_agent_guardrail" {
#   name                      = "example"
#   blocked_input_messaging   = "example"
#   blocked_outputs_messaging = "example"
#   description               = "example"

#   content_policy_config {
#     filters_config {
#       input_strength  = "MEDIUM"
#       output_strength = "MEDIUM"
#       type            = "HATE"
#     }
#     tier_config {
#       tier_name = "STANDARD"
#     }
#   }

#   sensitive_information_policy_config {
#     pii_entities_config {
#       action         = "BLOCK"
#       input_action   = "BLOCK"
#       output_action  = "ANONYMIZE"
#       input_enabled  = true
#       output_enabled = true
#       type           = "NAME"
#     }

#     regexes_config {
#       action         = "BLOCK"
#       input_action   = "BLOCK"
#       output_action  = "BLOCK"
#       input_enabled  = true
#       output_enabled = false
#       description    = "example regex"
#       name           = "regex_example"
#       pattern        = "^\\d{3}-\\d{2}-\\d{4}$"
#     }
#   }

#   topic_policy_config {
#     topics_config {
#       name       = "investment_topic"
#       examples   = ["Where should I invest my money ?"]
#       type       = "DENY"
#       definition = "Investment advice refers to inquiries, guidance, or recommendations regarding the management or allocation of funds or assets with the goal of generating returns ."
#     }
#     tier_config {
#       tier_name = "CLASSIC"
#     }
#   }

#   word_policy_config {
#     managed_word_lists_config {
#       type = "PROFANITY"
#     }
#     words_config {
#       text = "HATE"
#     }
#   }
# }

# resource "aws_bedrock_guardrail_version" "guardrail_version" {
#   description   = "example"
#   guardrail_arn = aws_bedrock_guardrail.texttosql_bedrock_agent_guardrail.guardrail_arn
#   skip_destroy  = true
# }
