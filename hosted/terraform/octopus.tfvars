# Tokenized variable file for Octopus Deploy CD runs.
# Octopus substitutes #{...} tokens before passing this file to Terraform.
#
# environment is NOT set here — it is hardcoded per module instance in main.tf.
# Target the relevant module in your Octopus runbook:
#   terraform apply -var-file=octopus.tfvars -target=module.web_app_dev
#   terraform apply -var-file=octopus.tfvars -target=module.web_app_test

resource_prefix = "#{Project.ResourcePrefix}"
