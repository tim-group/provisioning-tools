
define "puppetmaster" do
  extend Provision::Commands
  ubuntuprecise()

  options = @options

  run("puppet mastery"){
    cmd "echo 'building puppetmaster' #{hostname}"
  }
end
