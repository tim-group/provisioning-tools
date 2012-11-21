class MCollective::Application::Puppetupdate<MCollective::Application
  description "Puppet repository updates Client"
  usage "Usage: mco puppetupdate -T oyldn or mco puppetupdate <sha1>"

  def post_option_parser(configuration)
    if ARGV.length >= 1
      configuration[:command] = "update_default"
      configuration[:revision] = ARGV.shift
    else
      configuration[:command] = "update"
    end
  end

  def main

    case configuration[:command]
    when "update"
      mc = rpcclient("puppetupdate", :options => options)
      printrpc mc.update()
      mc.disconnect
      printrpcstats
    when "update_default"
      mc = rpcclient("puppetupdate", :options => options)
      printrpc mc.update_default(:revision=>configuration[:revision])
      mc.disconnect
      printrpcstats
    end

  end
end
