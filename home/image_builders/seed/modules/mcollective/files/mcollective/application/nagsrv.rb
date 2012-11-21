class MCollective::Application::Nagsrv<MCollective::Application
  def self.valid_commands
    %w( info show show-acknowledged enable-notify disable-notify acknowledge unacknowledge )
  end

  # Upon initialization, go ahead and create methods for each of the valid
  # commands using the basic_handler unless we've already defined a custom
  # method.
  def initialize
    klass = self
    self.class.instance_eval do
      valid_commands.each do |command|
        method = klass.handler_method(command)
        unless klass.respond_to?(method)
          define_method(method) { basic_handler }
        end
      end
    end
  end

  description 'Nagios manipulation using the ruby-nagios library'
  usage "nagsrv [#{valid_commands.join('|')}]"

  option :listhosts,
    :description => 'List hostnames that match certain criteria',
    :arguments   => ['--list-hosts'],
    :type        => :bool

  option :listservices,
    :description => 'List services that match certain criteria',
    :arguments   => ['--list-services'],
    :type        => :bool

  option :withservice,
    :description => 'Match a service or regular expression',
    :arguments   => ['--with-service SERVICE'],
    :type        => String

  option :withack,
    :description => 'List only services with an acknwoledgement',
    :arguments   => ['--with-ack'],
    :type        => :bool

  option :withoutack,
    :description => 'List only services without an acknwoledgement',
    :arguments   => ['--without-ack'],
    :type        => :bool

  option :forhost,
    :description => 'Restrict selection of services to a specific host',
    :arguments   => ['--for-host HOST'],
    :type        => String

  option :notify_enabled,
    :description => 'List only services with notification enabled',
    :arguments   => ['--notify-enabled'],
    :type        => :bool

  option :notify_disabled,
    :description => 'List only services with notification disabled',
    :arguments   => ['--notify-disabled'],
    :type        => :bool

  option :ackexpire,
    :description => 'Time in minutes before an ack expires, only used by ack subcommand',
    :arguments   => ['--ack-expire TIME'],
    :type        => String


  def post_option_parser(configuration)
    if ARGV.size >= 1
      configuration[:command] = ARGV.shift
    end

    # Acknowledgement requires a reason
    if configuration[:command] == 'acknowledge'
      configuration[:ackreason] = ARGV.join(' ')
    end

    configuration[:user] = ENV['USER']

    # Nagios stores notification and acknowledgedment data using 1 or 0
    if configuration[:notify_enabled] == true
      conifguration[:notifyenable] = 1
    end

    if configuration[:notify_disabled] == true
      configuration[:notifyenable] = 0
    end

    if configuration[:withack] == true
      configuration[:acknowledged] = 1
    end

    if configuration[:withoutack] == true
      configuration[:acknowledged] = 0
    end

    # User input is how many minutes from now to expire, nagios expects a
    # timestamp in epoch of when to expire.
    if configuration[:ackexpire]
      seconds_to_expire = configuration[:ackexpire].to_i * 60
      configuration[:ackexpire] = Time.now.to_i + seconds_to_expire
    end
  end

  def validate_configuration(configuration)
    unless self.class.valid_commands.include?(configuration[:command])
      raise "Command should be one of: #{self.class.valid_commands.join(', ')}"
    end

    if configuration[:command] == 'acknowledge'
      unless configuration[:ackreason]
        raise 'Acknowledgement requires a reason!'
      end
    end
  end

  def main
    # This is a fairly long running process
    options[:timeout] = 120 if options[:timeout] < 120

    # Since during initialization we have created all the valid commands
    # methods, all we have to do is send
    send(handler_method(configuration[:command]))
  end

  # Provide a way to assume our data exists by checking the status code. If
  # everything looks okay, go ahead and run the given block.
  def print_results(node, &block)
    print_status(node)
    if node[:statuscode] == 0
      yield
    end
  end

  def print_status(node)
    printf("%-40s %s\n", node[:sender], node[:statusmsg])
  end

  def nagsrv
    @nagsrv ||= rpcclient('nagsrv')
  end

  # If the action in the agent returns an array under the data key 'output',
  # just go ahead and print it.
  def basic_handler
    command = configuration.delete(:command)
    nagsrv.send(command, configuration).each do |node|
      print_results(node) do
        if node[:data][:output] && node[:data][:output].kind_of?(Array)
          puts node[:data][:output].join("\n")
        end
      end
    end
  end

  # Converts the given command into a valid symbol that will handle the rpc
  # request
  def handler_method(command)
    "handle_#{command.gsub('-', '_')}".to_sym
  end

  def handle_show_acknowledged
    command = configuration.delete(:command)
    nagsrv.send(command, configuration).each do |node|
      print_results(node) do
        hosts = node[:data][:output]
        hosts.each do |host, services|
          puts host
          services.each do |service_description, comments|
            puts "  #{service_description}"
            comments.each do |comment|
              puts "    #{comment['author']}: #{comment['comment_data']}"
            end
          end
          puts
        end
      end
    end
  end

  def handle_info
    nagsrv.send(configuration[:command]).each do |node|
      print_results(node) do
        if node[:data][:info] && node[:data][:info][:aggregate]
          aggregate = node[:data][:info][:aggregate]
          aggregate.keys.sort.each do |stat|
            printf("%20s: %s\n", stat, aggregate[stat])
          end
        end
      end
    end
  end
end
