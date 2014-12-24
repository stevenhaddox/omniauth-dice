require 'psych' # Fix double-load bug when requiring yaml
require 'yaml'
if File.exist?('config/gem_sources.yml')
  YAML.load_file('config/gem_sources.yml').each do |gem_source|
    puts "Loading gem source: #{gem_source}"
    source gem_source
  end
else
  source 'https://rubygems.org'
end

# Specify your gem's dependencies in omniauth-dice.gemspec
gemspec
