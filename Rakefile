require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

task default: [:spec, :rubocop]

desc 'Run specs'
RSpec::Core::RakeTask.new(:spec)

desc 'Run rubocop'
task :rubocop do
  RuboCop::RakeTask.new
end

desc 'Display TODOs, FIXMEs, and OPTIMIZEs'
task :notes do
  system("grep -r 'OPTIMIZE:\\|FIXME:\\|TODO:' #{Dir.pwd}")
end
