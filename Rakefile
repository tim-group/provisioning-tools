require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'fileutils'
require 'rspec/core/rake_task'


task :test => [:setup]
Rake::TestTask.new { |t|
    t.pattern = 'test/**/*_test.rb'
}

desc "Run specs"
RSpec::Core::RakeTask.new("sys_spec") do |t|
    t.rspec_opts = %w[--color]
    t.pattern = "test/sys_spec/**/*_spec.rb"
end
desc "Run specs"
RSpec::Core::RakeTask.new() do |t|
    t.rspec_opts = %w[--color]
    t.pattern = "test/spec/**/*_spec.rb"
end
