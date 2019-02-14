#!/usr/bin/env ruby

# This script will build a tgz file containing a copy of Postal with the assets
# ready to go.
#
# This script will only be used by the Postal build manager so it's likely of
# little use to most people.

require 'rubygems'
require 'pathname'
require 'fileutils'

ROOT = Pathname.new(File.expand_path('../../', __FILE__))
BUILD_ROOT = Pathname.new("/tmp/postal-build")
WC_PATH = BUILD_ROOT.join('wc')

CHANNEL = ARGV[0]

unless ['beta', 'stable'].include?(CHANNEL)
  puts "channel must be beta or stable"
  exit 1
end

def system!(c)
  if system(c)
    true
  else
    puts "Couldn't execute #{c.inspect}"
    exit 1
  end
end

# Prepare our build root
FileUtils.mkdir_p(BUILD_ROOT)

# Get a brand new clean copy of the repository
puts "\e[44;37mCloning clean repository\e[0m"
system!("rm -rf #{WC_PATH}")
system!("git clone #{ROOT} #{WC_PATH}")

# Install bundler dependencies so we can compile assets
puts "\e[44;37mInstalling dependencies\e[0m"
system!("cd #{WC_PATH} && bundle install --gemfile #{WC_PATH}/Gemfile --path #{BUILD_ROOT}/vendor/bundle")

# Install some configuration files
puts "\e[44;37mInstalling configuration\e[0m"
system!("cd #{WC_PATH} && ./bin/postal initialize-config")

# Get the last commit reference for the version file
last_commit = `cd #{ROOT} && git rev-parse --short HEAD | tr -d '\n'`
puts "\e[34mGot latest commit was #{last_commit}\e[0m"

PACKAGE_PATH = BUILD_ROOT.join("postal-ott-#{last_commit}.tgz")

# Compile all the assets
unless ENV['NO_ASSETS']
  puts "\e[44;37mCompiling assets\e[0m"
  system!("cd #{WC_PATH} && RAILS_GROUPS=assets bundle exec rake assets:precompile")
  system!("touch #{WC_PATH}/public/assets/.prebuilt")
end

# Remove files that shouldn't be distributed
puts "\e[44;37mRemoving unused files\e[0m"
system!("rm -Rf #{WC_PATH}/.git")
system!("rm -f #{WC_PATH}/config/postal.yml")
system!("rm -f #{WC_PATH}/config/*.cert")
system!("rm -f #{WC_PATH}/config/*.key")
system!("rm -f #{WC_PATH}/config/*.pem")
system!("rm -Rf #{WC_PATH}/.bundle")
system!("rm -Rf #{WC_PATH}/.gitignore")
system!("rm -Rf #{WC_PATH}/tmp")

File.open("#{WC_PATH}/version", 'w') { |f| f.write(last_commit) }

# Build a new tgz file
puts "\e[44;37mCreating build package\e[0m"
system("tar cpzf #{PACKAGE_PATH} -C #{WC_PATH} .")
puts "\e[32mCreated build at #{PACKAGE_PATH}\e[0m"
