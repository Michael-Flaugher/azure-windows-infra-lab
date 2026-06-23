variable "subscription_id" {
  description = "Your Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-infra-lab"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US 2"
}

variable "workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
  default     = "law-infra-lab"
}

variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
}
