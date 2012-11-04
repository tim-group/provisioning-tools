class NoopListener
  def initialize
    @errors = 0
  end

  def passed(spec)
    print "#{spec[:hostname]} \e[1;32m[passed]\e[0m\n"
  end
	
  def error(e,spec)
    @errors=@errors+1
    print "#{spec[:hostname]} \e[1;31m[failed #{e}]\e[0m \n"
  end

  def has_errors?
    return @errors>0
  end
end
