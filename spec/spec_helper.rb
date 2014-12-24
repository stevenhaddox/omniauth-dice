require 'rubygems'
require 'bundler'
Bundler.setup :default, :development, :test

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'capybara/rspec'
require 'webmock/rspec'
require 'awesome_print'
require 'rack/test'
require 'omniauth-dice'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.include Rack::Test::Methods
  config.filter_run :focus
  config.filter_run_excluding :skip

  config.include Rack::Test::Methods
  config.extend  OmniAuth::Test::StrategyMacros, :type => :strategy
end

# Load test app, stolen / customized from:
# https://github.com/railsware/rack_session_access/tree/master/apps
Dir[File.expand_path('spec/test_apps/*.rb'), __FILE__].each do |f|
  require f
end
