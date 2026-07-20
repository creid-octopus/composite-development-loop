output "webapp_configuration" {
  value = {
    development = {
      resource_group_name = module.web_app_development.resource_group_name
      app_name            = module.web_app_development.app_name
      app_url             = module.web_app_development.app_url
      slot_url            = module.web_app_development.feature_slot_url
    }
    test = {
      resource_group_name = module.web_app_test.resource_group_name
      app_name            = module.web_app_test.app_name
      app_url             = module.web_app_test.app_url
      slot_url            = module.web_app_test.feature_slot_url
    }
  }
}
