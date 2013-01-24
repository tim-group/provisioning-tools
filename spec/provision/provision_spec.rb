require 'rspec'
require 'provision'

describe Provision::Factory do
  it 'can be constructed' do
    Provision::Factory.new
  end

  it 'has a working home method' do
    Provision::Factory.new.home
  end

  it 'has a working base method' do
    Provision::Factory.new.base
  end
end

