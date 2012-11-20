class MCollective::Application::Aptupdate<MCollective::Application
  description "apt repository updates Client"
  usage "Usage: mco aptupdate -T oyldn"

  def main
    mc = rpcclient("aptupdate", :options => options)

    printrpc mc.update()

    mc.disconnect
    printrpcstats
  end
end
