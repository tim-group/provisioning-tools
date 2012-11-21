require 'find'

module MCollective
  module Registration
    # A registration plugin that sends in all the metadata we have for a node,
    # including:
    #
    # - all facts
    # - all agents
    # - all classes (if applicable)
    # - the configured identity
    # - the list of collectives the nodes belong to
    #
    # http://projects.puppetlabs.com/projects/mcollective-plugins/wiki/RegistrationMetaData
    # Author: R.I.Pienaar <rip@devco.net>
    # Licence: Apache 2
    class Meta<Base
      def body
        result = {:agentlist => [],
                  :facts => {},
                  :classes => [],
                  :collectives => []}

        cfile = Config.instance.classesfile

        if File.exist?(cfile)
          result[:classes] = File.readlines(cfile).map {|i| i.chomp}
        end

        result[:identity] = Config.instance.identity
        result[:agentlist] = Agents.agentlist
        result[:facts] = PluginManager["facts_plugin"].get_facts
        result[:collectives] = Config.instance.collectives.sort

        yaml_dir = Config.instance.pluginconf["registration.extra_yaml_dir"] || false
        # Optionally send a list of extra yaml files
        if (yaml_dir != false)
          result[:extra] = find_extra_yaml(yaml_dir)
        end

        result
      end

      def find_extra_yaml (path)
        if path !~ /\/$/
          path = "#{path}/"
        end
        count = path.split('/').count
        data = {}
        Dir[path + "*"].each do | f |
          parts = f.split('/')
          key_name = parts.slice(count, parts.count).join('/').split('.')[0]
          if File.directory?(f)
            data[key_name] = find_extra_yaml(f)
          else
            data[key_name] = YAML.load_file(f)
          end
        end
        data
      end
    end
  end
end
# vi:tabstop=2:expandtab:ai
