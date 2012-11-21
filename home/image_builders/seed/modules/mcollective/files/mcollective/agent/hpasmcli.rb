require 'fileutils'


module MCollective
  module Agent
    class Hpasmcli<RPC::Agent
      attr_accessor :dir

      metadata :name        => "HP ASM CLI",
         :description => "Agent to run the hpasmcli commands on servers",
         :author      => "Infrastructure Team",
         :license     => "MIT",
         :version     => "1.0",
         :url         => "http://www.timgroup.com",
         :timeout     => 120

      def initialize
        if ENV["HPASMCLI"] == nil
         @hpasmcli = "/sbin/hpasmcli"
        else
          @hpasmcli = ENV["HPASMCLI"]
        end

        @debug=false
        super
      end

      action "run" do
        reply[:response] = run(request[:cmd])
      end

      def run(query)
        begin
          response = exec("#{@hpasmcli} -s '#{query}'")
        rescue Exception => e
          response = "Exception: #{e}"
        end
        return response
      end

      def debug(line)
        if true == @debug
          logger.info(line)
        end
      end

      def exec(cmd)
         debug "Running cmd #{cmd}"
         output=`#{cmd} 2>&1`
         if not $?.success?
           raise "#{cmd} failed with: #{output}"
         end
         return output
       end


    end
  end
end

