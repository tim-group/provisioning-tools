
define "puppetmaster" do
  extend Provision::Commands
  ubuntuprecise()

  options = @options

  run("puppet mastery"){
    hostname = @options[:hostname]
    cmd "echo 'building puppet' #{hostname}"
  }
end