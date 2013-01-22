require 'provision'

describe Provision do


  it 'throws an error when there is an error in the config' do

    class Provision::Config
      def load()
        return {
        }
      end

      def required_config_keys()
        ['dns_backend']
      end

    end

    expect {
      config = Provision::Config.new(:configfile=>"/etc/provision/config.yaml")
      config.get()
    }.to raise_error("/etc/provision/config.yaml has missing properties (dns_backend)")

  end
end

