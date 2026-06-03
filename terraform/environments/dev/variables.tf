variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Central US"
}

variable "resource_prefix" {
  description = "Prefix applied to all resource names"
  type        = string
  default     = "creid-devloop"
}

variable "sku_name" {
  description = "App Service Plan SKU — must support deployment slots (S1 or higher)"
  type        = string
  default     = "S1"
}
