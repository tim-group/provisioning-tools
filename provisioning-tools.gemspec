require 'rake'
Gem::Specification.new do |s|
  s.name        = 'provisioning-tools'
  s.version     = '0.0.0'
  s.date        = '2012-11-03'
  s.summary     = "Provisioning tools for building gold images"
  s.description = "Provisioning tools for building gold images and other libraries"
  s.authors     = ["Tomas Doran"]
  s.email       = 'tomas.doran@youdevise.com'
  s.files       = FileList['lib/**/*.rb',
                            'bin/*',
                            '[A-Z]*',
                            'test/**/*'].to_a
end

