require 'provision'
require 'rspec'
require 'yaml'
require 'tempfile'
require 'rspec/expectations'

describe Provision::Config do
  it 'Blows up when config is empty' do
    f = Tempfile.new('test_yaml')
    f.puts({}.to_yaml)
    f.close
    expect do
      Provision::Config.new(:configfile => f.path).get
    end.to raise_error("#{f.path} has missing properties (dns_backend, dns_backend_options, networks)")
  end

  it 'Can load a config in either sym form or raw form' do
    d = {
      :dns_backend => 'baz',
      :dns_backend_options => {},
      :networks => {}
    }
    d2 = {
      'dns_backend' => 'baz',
      'dns_backend_options' => {},
      'networks' => {}
    }
    f = Tempfile.new('test_yaml')
    f.puts(d.to_yaml)
    f.close
    c = Provision::Config.new(:configfile => f.path)
    c.get.should eql(d)
    f2 = Tempfile.new('test_yaml')
    f2.puts(d2.to_yaml)
    f2.close
    c2 = Provision::Config.new(:configfile => f2.path)
    c2.get.should eql(d)
  end

  it 'recurses when applying sym form' do
    exp = {
      :dns_backend => 'baz',
      :dns_backend_options => { :foo => 'bar' },
      :networks => {}
    }
    send = {
      'dns_backend' => 'baz',
      'dns_backend_options' => { 'foo' => 'bar' },
      'networks' => {}
    }
    f = Tempfile.new('test_yaml')
    f.puts(send.to_yaml)
    f.close
    c = Provision::Config.new(:configfile => f.path)
    c.get.should eql(exp)
  end
end
