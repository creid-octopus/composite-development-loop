# Tokenized variable file for Octopus Deploy CD runs.
# Octopus substitutes #{...} tokens before passing this file to Terraform.
# environment is not set here — it is hardcoded as "dev" in main.tf.

resource_prefix = "#{Project.ResourcePrefix}"
