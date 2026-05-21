variable "environment" {
  description = "Short environment label (e.g. test, staging, prod)"
  type        = string
  default     = "test"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "Central US"
}

variable "resource_prefix" {
  description = "Prefix applied to all resource names"
  type        = string
  default     = "creid-devloop"
}

variable "sku_name" {
  description = "App Service Plan SKU (S1 - this is a demo but we still need slots)"
  type        = string
  default     = "S1"
}
