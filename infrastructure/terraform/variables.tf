variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m5.xlarge"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH to the instance (e.g., your IP/32)"
  type        = string
  default     = "0.0.0.0/0" # Change this to your IP for security
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 50
}

