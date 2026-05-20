terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  # backend "s3" {
  #   bucket         = "texttosqltfstate"   # pre-create this manually
  #   key            = "terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "texttosqltfstatelock"          # pre-create this too
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

provider "random" {
  # Configuration options
}