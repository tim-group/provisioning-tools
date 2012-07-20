define "conventions" do
  extend Provision::Image::Commands

  @options['diskimg'] = @options['diskimg'] || "#{@options['hostname']}.img"
  @options['disksize'] = @options['disksize'] || '3G'

  makevar(:loop0, @options['loop0'])
  makevar(:loop1, @options['loop1'])

  @options.keys.each {|key|
    makevar(key.to_sym, @options[key])
  }	

  makevar(:temp_dir, hostname)
  #+ rand(36**8).to_s(36)

  run ("xxx") {
  }
end
