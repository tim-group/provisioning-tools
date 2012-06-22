define "conventions" do
  @options['diskimg'] = @options['diskimg'] || "#{@options['hostname']}.img"
  @options['disksize'] = @options['disksize'] || '3G'
  makevar(:temp_dir, 'vmtmp-')


  @options.keys.each {|key|
    makevar(key.to_sym, @options[key])
  }	

  #+ rand(36**8).to_s(36)

end
