require 'provisioning-tools/provision'

describe Provision::Factory do
  TEST_CONFIG = File.join(File.dirname(__FILE__), "config.yaml")

  it 'can be constructed' do
    Provision::Factory.new(:configfile => TEST_CONFIG)
  end
end
