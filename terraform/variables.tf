variable "ssh_public_key_path" {
  description = "Path to this account's SSH public key. Keep account-specific tfvars out of Git."
  type        = string
}

variable "db_admin_cidr" {
  description = "Administrator's public IPv4 address in CIDR notation, for example 203.0.113.10/32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.db_admin_cidr)) && endswith(var.db_admin_cidr, "/32")
    error_message = "db_admin_cidr must be one IPv4 address with a /32 mask."
  }
}

variable "database_instance_type" {
  description = "EC2 instance type for the database host."
  type        = string
  default     = "t3.micro"
}

variable "app_security_group_id" {
  description = "Optional application security group allowed to reach the database port."
  type        = string
  default     = null
  nullable    = true
}

variable "database_port" {
  description = "Database listener port to allow from the application security group."
  type        = number
  default     = 5432

  validation {
    condition     = var.database_port >= 1 && var.database_port <= 65535
    error_message = "database_port must be between 1 and 65535."
  }
}
