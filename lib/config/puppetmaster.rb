extend Provision::Commands

define "puppetmaster" do
  ubuntuprecise()

  options = @options

  run("puppet mastery"){
    hostname = @options[:hostname]
    cmd "echo 'building puppet' #{hostname}"
  }
end