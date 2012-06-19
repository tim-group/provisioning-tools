require 'thread'

q = Queue.new

20.times { |i|
  q<<"#{i}"
}
threads = []

3.times { |i|
  threads << Thread.new {
    begin
      while ((something = q.pop(true))!=nil)
        print "t#{i} #{something}\n"
        sleep 1
      end
    rescue

    ensure
      print "t#{i} done\n"
    end
  }
}

threads.each {|thread|thread.join()}
