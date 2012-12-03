require 'rake'
hash = `cat ".git/$(cat .git/HEAD | cut -d' ' -f2)" | head -c 7`
v_part = ENV['BUILD_NUMBER'] || "0.pre.#{hash}" # 0.pre to make debian consider any pre-release cut from git
                                                # version of the package to be _older_ than the last CI build.
version = "0.0.#{v_part}"

Gem::Specification.new do |s|
  s.name        = 'provisioning-tools'
  s.version     = version
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

