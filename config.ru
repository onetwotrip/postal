# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'
$0="[postal] #{ENV['PROC_NAME']}"

if Rails.env.profile?
  use Rack::RubyProf, :path => '/tmp/postal/profile'
end

run Rails.application
