# environment is intentionally absent here — it is hardcoded per module instance
# in main.tf ("dev" / "test") rather than driven by a tfvars input.
# Use -var-file=octopus.tfvars (CD) or -var-file=local.tfvars (local testing)
# to override the infrastructure-level variables below.

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Central US"
}

variable "resource_prefix" {
  description = "Prefix applied to all resource names (e.g. creid-devloop → creid-devloop-dev-plan)"
  type        = string
  default     = "creid-devloop"
}

variable "sku_name" {
  description = "App Service Plan SKU — must support deployment slots (S1 or higher)"
  type        = string
  default     = "S1"
}
