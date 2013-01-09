require 'rake'
require File.join(File.dirname(__FILE__), "version")

Gem::Specification.new do |s|
  s.name        = 'provisioning-tools'
  s.version     = version()
  s.date        = Time.now.strftime("%Y-%m-%d")
  s.summary     = "Provisioning tools for building gold images"
  s.description = "Provisioning tools for building gold images and other libraries"
  s.authors     = ["Tomas Doran"]
  s.email       = 'tomas.doran@youdevise.com'
  s.files       = FileList['lib/**/*.rb',
                           'bin/*',
                           'home/**/*',
                           'templates/**/*',
                           '[A-Z]*',
                           'test/**/*'].to_a
end

