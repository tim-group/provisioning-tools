require 'rspec'
require 'provision'
require 'provision/storage'

describe Provision do
  before do
    @storage = Provision::Storage.new({})
  end

  describe '#run_task' do
    it 'runs a task' do
      @storage.run_task('test',{
        :task => lambda {
          @storage.cmd('true')
        }
      })
    end

    it 'runs the on_error lamdba if the task fails' do
      @pretend_object = double()
      @pretend_object.should_receive(:blah)

      expect {
        @storage.run_task('test',{
          :task => lambda {
            @storage.cmd('false')
          },
          :on_error => lambda {
            @pretend_object.blah()
          }
        })
      }.to raise_error
    end

    it 'adds a lambda to the cleanup_tasks hash if the task is successful' do
      @pretend_object = double()
      @pretend_object.should_receive(:blah)

      @storage.run_task('test',{
        :task => lambda {
          @storage.cmd('true')
        },
        :cleanup => lambda {
          @pretend_object.blah()
        }
      })

      Provision::Storage.cleanup('test')
    end

    it 'performs cleanup tasks in reverse order' do
      @pretend_object = double()
      @pretend_object.should_receive(:blah2).ordered
      @pretend_object.should_receive(:blah1).ordered

      @storage.run_task('test',{
        :task => lambda {
          @storage.cmd('true')
        },
        :cleanup => lambda {
          @pretend_object.blah1()
        }
      })

      @storage.run_task('test',{
        :task => lambda {
          @storage.cmd('true')
        },
        :cleanup => lambda {
          @pretend_object.blah2()
        }
      })

      expect {
        @storage.run_task('test',{
          :task => lambda {
            @storage.cmd('false')
          },
        })
      }.to raise_error

      Provision::Storage.cleanup('test')
    end

    it 'removes a task from the cleanup tasks if one is specified in cleanup_remove of a task that succeeds' do
      @pretend_object = double()
      @pretend_object.should_receive(:blah1).ordered

      @storage.run_task('test',{
        :task => lambda {
          @storage.cmd('true')
        },
        :cleanup => lambda {
          @pretend_object.blah1()
        }
      })

      cleanup_lambda = lambda {
        @pretend_object.blah2()
      }

      @storage.run_task('test',{
        :task => lambda {
          @storage.cmd('true')
        },
        :cleanup => cleanup_lambda
      })

      @storage.run_task('test',{
        :task => lambda {
          @storage.cmd('true')
        },
        :cleanup_remove => cleanup_lambda
      })

      expect {
        @storage.run_task('test',{
          :task => lambda {
            @storage.cmd('false')
          },
        })
      }.to raise_error

      Provision::Storage.cleanup('test')
    end

    it 'does not remove cleanup tasks if a task fails' do
      @pretend_object = double()
      @pretend_object.should_receive(:blah2).ordered
      @pretend_object.should_receive(:blah1).ordered

      @storage.run_task('test',{
        :task => lambda {
          @storage.cmd('true')
        },
        :cleanup => lambda {
          @pretend_object.blah1()
        }
      })

      cleanup_lambda = lambda {
        @pretend_object.blah2()
      }

      @storage.run_task('test',{
        :task => lambda {
          @storage.cmd('true')
        },
        :cleanup => cleanup_lambda
      })

      expect {
        @storage.run_task('test',{
          :task => lambda {
            @storage.cmd('false')
          },
          :cleanup_remove => cleanup_lambda
        })
      }.to raise_error

      Provision::Storage.cleanup('test')
    end
  end
end
