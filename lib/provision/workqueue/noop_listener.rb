class NoopListener
  attr_reader :results

  class InternalLogger
    def info(msg)
      print "\e[1;32m#{msg}\e[0m\n"
    end

    def warn(msg)
      print "\e[1;31m#{msg}\e[0m\n"
    end
  end

  def initialize(options={})
    @errors = 0
    @results = {}
    @logger = options[:logger] || InternalLogger.new
  end

  def passed(spec)
    @results[spec[:hostname]] = "success"
    @logger.info("#{spec[:hostname]} [passed]")
  end

  def error(e,spec)
    @results[spec[:hostname]] = "failed"
    @errors=@errors+1
    @logger.warn("#{spec[:hostname]} [failed] - #{e}")
  end

  def has_errors?
    return @errors>0
  end
end

