require 'rubygems'
require 'nagios/status'

module Nagios
  class Status
    # Override find_services to allow searching by acknowledgement
    def find_services(options = {})
      forhost = options.fetch(:forhost, [])
      notifications = options.fetch(:notifyenabled, nil)
      acknowledged = options.fetch(:acknowledged, nil)
      action = options.fetch(:action, nil)
      withservice = options.fetch(:withservice, [])

      services = []
      searchquery = []

      # Build up a search query for find_with_properties each
      # array member is a hash of property and a match
      forhost.each do |host|
        searchquery << search_term("host_name", host)
      end

      withservice.each do |s|
        searchquery << search_term("service_description", s)
      end

      searchquery << {"notifications_enabled" => notifications.to_s} if notifications
      searchquery << {"problem_has_been_acknowledged" => acknowledged.to_s} if acknowledged

      svcs = find_with_properties(searchquery)

      svcs.each do |service|
        service_description = service["service_description"]
        host_name = service["host_name"]

        # when printing services with notifications en/dis it makes
        # most sense to print them in host:service format, abuse the
        # action option to get this result
        action = "${host}:${service}" if (notifications != nil && action == nil)

        services << parse_command_template(action, host_name, service_description, service_description)
      end

      services.uniq.sort
    end

    def send_find_with_properties(term, value, action='${host}:${service}')
      services = []
      searchquery = [ search_term(term, value.to_s) ]

      find_with_properties(searchquery).each do |service|
        service_description = service['service_description']
        host_name = service['host_name']
        services << parse_command_template(action, host_name, service_description, service_description)
      end

      services.uniq.sort
    end

    def find_services_with_property(term, value)
      searchquery = [ search_term(term, value.to_s) ]
      find_with_properties(searchquery)
    end

    def get_servicecomments(host)
      @status['hosts'][host]['servicecomments']
    end
  end
end

module MCollective
  module Agent
    class Nagsrv<RPC::Agent
      metadata  :name        => 'Nagsrv Agent',
                :description => 'An agent that will manipulate nagios using the ruby-nagios library',
                :license     => 'Apache 2.0',
                :author      => 'crazed',
                :version     => '0.1',
                :url         => 'github.com/crazed/mcollective-nagsrv',
                :timeout     => 120

      def nagios
        return @nagios if @nagios
        @nagios = Nagios::Status.new
        @nagios.parsestatus(nagios_status_log)
        @nagios
      end

      def nagios_status_log
        config.pluginconf['nagsrv.status_log'] || '/var/log/nagios/status.log'
      end

      def nagios_command_file
        config.pluginconf['nagsrv.command_file'] || '/var/nagios/rw/nagios.cmd'
      end

      def critical_services
        nagios.send_find_with_properties('current_state', 2)
      end

      def warning_services
        nagios.send_find_with_properties('current_state', 1)
      end

      def ok_services
        nagios.send_find_with_properties('current_state', 0)
      end

      def notifications_disabled
        nagios.send_find_with_properties('notifications_enabled', 0)
      end

      def write_commands_from_request(action)
        options = parse_request
        options[:action] = action
        commands = nagios.find_services(options)
        write_commands(commands)
        reply[:output] = commands
      end

      action 'enable-notify' do
        write_commands_from_request("[${tstamp}] ENABLE_SVC_NOTIFICATIONS;${host};${service}")
      end

      action 'disable-notify' do
        write_commands_from_request("[${tstamp}] DISABLE_SVC_NOTIFICATIONS;${host};${service}")
      end

      action 'acknowledge' do
        validate :ackreason, String
        validate :user, String

        if request.include?(:ackexpire)
          command_template = "[${tstamp}] ACKNOWLEDGE_SVC_PROBLEM_EXPIRE;${host};${service};1;0;1;#{request[:ackexpire]};#{request[:user]};#{request[:ackreason]}"
        else
          command_template = "[${tstamp}] ACKNOWLEDGE_SVC_PROBLEM;${host};${service};1;0;1;#{request[:user]};#{request[:ackreason]}"
        end
        write_commands_from_request(command_template)
      end

      action 'unacknowledge' do
        write_commands_from_request("[${tstamp}] REMOVE_SVC_ACKNOWLEDGEMENT;${host};${service}")
      end

      action 'show' do
        options = parse_request
        reply[:output] = nagios.find_services(options)
      end

      action 'show-acknowledged' do
        results = {}
        nagios.find_services_with_property('problem_has_been_acknowledged', 1).each do |service|
          service_description = service['service_description']
          host_name = service['host_name']
          results[host_name] ||= {}
          comments = nagios.get_servicecomments(host_name)[service_description]
          results[host_name][service_description] = comments
        end
        reply[:output] = results
      end

      action 'info' do
        services = {
          :ok                     => ok_services,
          :warning                => warning_services,
          :critical               => critical_services,
          :notifications_disabled => notifications_disabled,
        }
        aggregate = {
          :services_ok        => services[:ok].size,
          :services_warning   => services[:warning].size,
          :services_critical  => services[:critical].size,
          :services_no_notify => services[:notifications_disabled].size,
        }
        reply[:info] = {
          :services  => services,
          :aggregate => aggregate,
        }
      end

      private

      # Parse through the request options and return a hash compatible
      # with ruby-nagios
      def parse_request
        data = request.data
        acknowledged = data.fetch(:acknowledged, nil)
        action = data.fetch(:action, nil)
        forhost = data.fetch(:forhost, [])
        listhosts = data.fetch(:listhosts, false)
        listservices = data.fetch(:listservices, false)
        notifyenable = data.fetch(:notifyenable, nil)
        withservice = data.fetch(:withservice, [])

        if listservices && action == nil
          action = "${service}"
        end

        if listhosts || action.nil?
          action = "${host}" if action == nil
          forhost = "/." if forhost.size == 0
        end

        {
          :acknowledged  => acknowledged,
          :action        => action,
          :forhost       => forhost,
          :notifyenabled => notifyenable,
          :withservice   => withservice,
        }
      end

      # List is expected to be an array of nagios commands
      def write_commands(list)
        raise 'list must be an array!' unless list.kind_of?(Array)

        File.open(nagios_command_file, 'a') do |fh|
          fh.write(list.join("\n"))
        end
      end

    end
  end
end
