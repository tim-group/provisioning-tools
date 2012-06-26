require 'logger'
module Provision
  @@log = Logger.new("provision.log")
  def self.log()
    return @@log
  end
end