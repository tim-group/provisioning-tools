define "conventions" do
  extend Provision::Image::Commands
  @options.keys.each {|key|
    makevar(key.to_sym, @options[key])
  }	

  @build_dir = "build"
  @options['diskimg'] = @options['diskimg'] || "#{@options['hostname']}.img"
  @options['disksize'] = @options['disksize'] || '3G'

  makevar(:loop0, "loop#{@thread_number*2}")
  makevar(:loop1, "loop#{@thread_number*2+1}")

  makevar(:logdir, "#{@build_dir}/logs")
  makevar(:console_log, "#{@build_dir}/console-#{@thread_number}.log")
  makevar(:temp_dir, "#{@build_dir}/#{hostname}")
  #+ rand(36**8).to_s(36)

  run ("xxx") {
  }
end
