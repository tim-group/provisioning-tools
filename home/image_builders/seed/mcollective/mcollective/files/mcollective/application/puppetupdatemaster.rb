class MCollective::Application::Puppetupdatemaster<MCollective::Application
  description "Puppet repository updates Client"
  usage "Usage: mco puppetupdate -T oyldn"

  option :hash,
         :description    => "the hash to checkout",
         :arguments      => ["-h", "--hash HASH"],
         :required       => true

  def main
    hash = configuration[:hash]
    print "updating puppetmasters to #{hash}"
    mc = rpcclient("puppetupdate", :options => options)
    printrpc mc.update_master(:hash=>hash)
    mc.disconnect
    printrpcstats
  end
end
