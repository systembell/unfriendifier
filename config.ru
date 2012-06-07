require File.join(File.dirname(__FILE__), 'lib', 'unfriendifier.rb')
require 'bundler'

Bundler.require

require 'resque/server'

require 'date'
require 'openssl'

set :environment, :production 

run Rack::URLMap.new \
  "/" => Unfriendifier,
  "/resque" => Resque::Server.new
