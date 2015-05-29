require 'spec_helper'
require 'provisioning-tools/provision/core/machine_spec'

describe Provision::Core::MachineSpec do
  it 'fields in the spec hash are available as accessor methods' do
    machine_spec = Provision::Core::MachineSpec.new(:f1 => 5, :f2 => 25)
    machine_spec[:f1].should eql(5)
    machine_spec[:f2].should eql(25)
  end

  it 'when I define a variable that is nil the value holds' do
    machine_spec = Provision::Core::MachineSpec.new(:value1 => 5, :value2 => 25)
    machine_spec.if_nil_define_var(:value1, 18)
    machine_spec[:value1].should eql(5)
    machine_spec[:value2].should eql(25)
  end

  it 'when I define a variable that is not nil the value does not get replaced' do
    machine_spec = Provision::Core::MachineSpec.new(:value2 => 25)
    machine_spec.if_nil_define_var(:value1, 18)
    machine_spec[:value1].should eql(18)
    machine_spec[:value2].should eql(25)
  end

  it 'can set the var directly if needed' do
    machine_spec = Provision::Core::MachineSpec.new(:value1 => 5, :value2 => 25)
    machine_spec[:value1] = 18
    machine_spec[:value1].should eql(18)
    machine_spec[:value2].should eql(25)
  end

  it 'renders a valid xml from the template' do
    machine_spec = Provision::Core::MachineSpec.new(:value1 => 5, :value2 => 25)
  end
end
