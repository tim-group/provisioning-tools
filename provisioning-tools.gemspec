require 'rake'

hash = `git rev-parse --short HEAD`.chomp
v_part= ENV['BUILD_NUMBER'] || "0.pre.#{hash}"
version = "0.0.#{v_part}"

Gem::Specification.new do |s|
  s.name        = 'provisioning-tools'
  s.version     = version
  s.date        = Time.now.strftime("%Y-%m-%d")
  s.summary     = "Provisioning tools for building gold images"
  s.description = "Provisioning tools for building gold images and other libraries"
  s.authors     = ["Tomas Doran"]
  s.email       = 'tomas.doran@youdevise.com'
  s.files       = FileList[
    'lib/**/*.rb',
    'bin/*',
    'home/**/*',
    'templates/**/*',
    '[A-Z]*',
    'test/**/*'].to_a
  s.executables << 'dns'
  s.executables << 'gold'
  s.executables << 'provision'
end

