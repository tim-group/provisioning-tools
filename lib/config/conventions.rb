define "conventions" do
  @options['diskimg'] = @options['diskimg'] || "#{@options['hostname']}.img"
  @options['disksize'] = @options['disksize'] || '3G'
#  make_var(:temp_dir, 'vmtmp-')

  #+ rand(36**8).to_s(36)

end