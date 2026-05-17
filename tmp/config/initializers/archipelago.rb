Archipelago.configure do |config|
  config.root_namespace = "Islands"
  config.current_user_method = :current_user
  config.authorize_by_default = true
  config.strict_origin_check = false
  config.allowed_redirect_hosts = []
end
