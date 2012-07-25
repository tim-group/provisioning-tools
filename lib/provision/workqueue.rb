require 'provision/namespace.rb'
require 'thread'
require 'curses'

class Provision::WorkQueue
 include Curses
 def initialize(args)
    @provisioning_service = args[:provisioning_service]
    @worker_count = args[:worker_count]
    @queue = Queue.new
  end

  def add(spec)
    @queue << spec
  end

  def process()
    threads = []
    total = @queue.size()

    completed = 0
    errors = 0
    thread_progress = []
    build_objects = []
    @worker_count.times {|i|
      threads << Thread.new {
        while(not @queue.empty?)
          spec = @queue.pop(true)
          spec[:thread_number] = i
	  require 'yaml'
          thread_progress[i] = spec
          begin
            build_objects << @provisioning_service.provision_vm(spec)
          rescue Exception => e
            errors+=1
          ensure
            completed+=1
          end
        end
      }
    }

   while(false) #completed<total)
     Curses.clear
     Curses.start_color
     Curses.init_pair(COLOR_BLUE,COLOR_BLUE,COLOR_BLACK)
     Curses.init_pair(COLOR_RED,COLOR_RED,COLOR_BLACK)
     Curses.init_pair(COLOR_GREEN,COLOR_GREEN,COLOR_BLACK)
     Curses.setpos(0,0)

     Curses.attron(color_pair(COLOR_BLUE)|A_BOLD){
       offset = 0
       thread_progress.each {|thread|
        if thread!=nil
           Curses.addstr("thread #{thread[:thread_number]}")
           Curses.addstr(" building: #{thread[:hostname]}\n")
	end
       }

       Curses.addstr("\ncompleted: #{completed} / #{total} machines\n");
       color=COLOR_GREEN
       if(errors>0)
	     Curses.attron(color_pair(COLOR_RED)|A_BOLD){
	       Curses.addstr("#{errors} / #{completed} machines failed to build");

	     }

	else
	     Curses.attron(color_pair(COLOR_GREEN)|A_BOLD){
	       Curses.addstr("#{errors} / #{completed} machines failed to build");

	     }


       end
       }


     Curses.refresh
     sleep 0.5
    end

    threads.each {|thread| thread.join()}
    return build_objects
  end
end
