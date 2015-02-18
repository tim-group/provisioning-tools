require 'rake'

hash = `git rev-parse --short HEAD`.chomp
v_part= ENV['BUILD_NUMBER'] || "0.#{hash.hex}"
version = "0.0.#{v_part}"

Gem::Specification.new do |s|
  s.name        = 'provisioning-tools'
  s.version     = version
  s.date        = Time.now.strftime("%Y-%m-%d")
  s.summary     = "Provisioning tools for building gold images"
  s.description = "Provisioning tools for building gold images and other libraries"
  s.authors     = ["TIM Group Infra"]
  s.email       = 'infra@timgroup.com'
  s.files       = FileList[
    'lib/**/*.rb',
    'bin/*',
    'home/**/*',
    'templates/**/*',
    'files/**/*',
    '[A-Z]*',
    'test/**/*'].to_a
  s.executables << 'dns'
  s.executables << 'provision'
end

