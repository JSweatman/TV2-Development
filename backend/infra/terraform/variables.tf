variable "aws_region" { type=string default="us-east-2" }
variable "db_instance_class" { type=string default="db.t4g.micro" }
variable "db_password" { type=string sensitive=true }
