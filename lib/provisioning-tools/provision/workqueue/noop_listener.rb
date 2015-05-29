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

  def initialize(options = {})
    @results = {}
    @logger = options[:logger] || InternalLogger.new
  end

  def passed(spec, msg = "")
    @results[spec[:hostname]] = ["success", msg]
    @logger.info("#{spec[:hostname]} [passed] #{msg}")
  end

  def error(spec, e)
    @results[spec[:hostname]] = ["failed", e.to_s]
    @logger.warn("#{spec[:hostname]} [failed] #{e}")
    @logger.warn(e.backtrace)
  end

  def failures
    results.select { |_k, v| v[0] == "failed" }
  end
end
