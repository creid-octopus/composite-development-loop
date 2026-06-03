variable "environment" {
  description = "Short environment label — used in resource names and Octopus discovery tags (e.g. dev, test)"
  type        = string
}

variable "location" {
  description = "Azure region for all resources in this module instance"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix applied to all resource names"
  type        = string
}

variable "sku_name" {
  description = "App Service Plan SKU — must support deployment slots (S1 or higher)"
  type        = string
  default     = "S1"
}
