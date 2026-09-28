terraform { required_version=">= 1.7.0" required_providers { aws={ source="hashicorp/aws" version="~> 6.0" } } }
provider "aws" { region=var.aws_region }
# Network, RDS, ECS/Fargate, ALB and ECR will be added/locked during the guided AWS deployment.
# Keeping this file intentionally small prevents us from creating unnecessary infrastructure before review.
