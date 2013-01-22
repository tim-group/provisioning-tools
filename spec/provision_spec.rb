require 'provision'

describe Provision do


  it 'throws an error when there is an error in the config' do

    class Provision::Config
      def load()
        return {
          :missing_stuff => 1
        }
      end
    end

    expect {
      config = Provision::Config.new(:configfile=>"/etc/provision/config.yaml")
      config.get()
    }.to raise_error("/etc/provision/config.yaml has missing properties")

  end

end
