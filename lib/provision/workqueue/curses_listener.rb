require 'curses'

class CursesListener
  attr_accessor :errors

  include Curses
  
  def initialize
    @errors = []
  end
  
  def error(e)
    @errors << e
  end
  
  def update(options)
    completed = options[:completed]
    errors = options[:errors]

    Curses.clear
    Curses.start_color
    Curses.init_pair(COLOR_BLUE,COLOR_BLUE,COLOR_BLACK)
    Curses.init_pair(COLOR_RED,COLOR_RED,COLOR_BLACK)
    Curses.init_pair(COLOR_GREEN,COLOR_GREEN,COLOR_BLACK)
    Curses.setpos(0,0)

    Curses.attron(color_pair(COLOR_BLUE)|A_BOLD){
      offset = 0
      #      thread_progress.each {|thread|
      #        if thread!=nil
      #          Curses.addstr("thread #{thread[:thread_number]}")
      #          Curses.addstr(" building: #{thread[:hostname]}\n")
      #        end
      #      }
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
    sleep 0.3
  end
end
