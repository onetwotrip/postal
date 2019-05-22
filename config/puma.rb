require_relative '../lib/postal/config'
threads_count = Postal.config.web_server&.max_threads&.to_i || 5
threads         threads_count, threads_count
workers_count = Postal.config.web_server&.workers || 4
workers         workers_count
if Postal.config.web_server&.preload_app
  preload_app!
end
bind_address  = Postal.config.web_server&.bind_address || '127.0.0.1'
bind_port     = Postal.config.web_server&.port&.to_i || 5000
bind            "tcp://#{bind_address}:#{bind_port}"
control_address = Postal.config.web_server&.control_address || '127.0.0.1'
control_port    = Postal.config.web_server&.control_port&.to_i || '9293'
control_token   = Postal.config.web_server&.control_token || 'foo'
activate_control_app "tcp://#{control_address}:#{control_port}", { auth_token: control_token}
environment     Postal.config.rails&.environment || 'development'
prune_bundler
quiet false
unless ENV['LOG_TO_STDOUT']
  stdout_redirect Postal.log_root.join('puma.log'), Postal.log_root.join('puma.log'), true
end

if ENV['APP_ROOT']
  directory ENV['APP_ROOT']
end
