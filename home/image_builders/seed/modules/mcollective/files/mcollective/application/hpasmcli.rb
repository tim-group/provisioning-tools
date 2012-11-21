class MCollective::Application::Hpasmcli<MCollective::Application
  description "Run the hpasmcli command on servers"
  usage "Usage: mco hpasmcli 'SHOW SERVER' -T oyldn"

  def main
    configuration[:command] = ARGV.shift if ARGV.size > 0

    hpasmcli = rpcclient("hpasmcli")
    hpasmcli.runcommand(:command => configuration[:command])


   # mc.disconnect
    printrpcstats
    #
  end
end
