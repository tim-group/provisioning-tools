class NoopListener
  attr_reader :results

  def initialize
    @errors = 0
    @results = {}
  end

  def passed(spec)
    @results[spec[:hostname]] = "success"
    print "#{spec[:hostname]} \e[1;32m[passed]\e[0m\n"
  end

  def error(e,spec)
     @results[spec[:hostname]] = "failed"
     @errors=@errors+1
    print "#{spec[:hostname]} \e[1;31m[failed #{e}]\e[0m \n"
  end

  def has_errors?
    return @errors>0
  end
end
