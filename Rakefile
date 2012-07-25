require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'fileutils'
require 'rspec/core/rake_task'


task :test => [:setup]
Rake::TestTask.new { |t|
    t.pattern = 'test/**/*batch*_test.rb'
}

desc "Run specs"
RSpec::Core::RakeTask.new() do |t|
    t.rspec_opts = %w[--color]
    t.pattern = 'spec/**/*batch*_spec.rb'
end

