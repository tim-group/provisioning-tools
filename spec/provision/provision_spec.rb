require 'rspec'
require 'provision'

describe Provision::Factory do
  TEST_CONFIG = File.join(File.dirname(__FILE__), "config.yaml")

  it 'can be constructed' do
    Provision::Factory.new(:configfile => TEST_CONFIG)
  end

  it 'has a working home method' do
    Provision::Factory.new(:configfile => TEST_CONFIG).home
  end

  it 'has a working base method' do
    Provision::Factory.new(:configfile => TEST_CONFIG).base
  end
end
