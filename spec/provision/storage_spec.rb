require 'rspec'
require 'provision'
require 'provision/storage'

describe Provision do
  before do
    @storage = Provision::Storage.new({})
  end

  describe '#run_task' do
    it 'runs a task' do
      @storage.run_task('test', 'run true', :task => lambda do
        @storage.cmd('true')
      end)
    end

    it 'adds a lambda to the cleanup_tasks hash if the task is successful' do
      pretend_object = double
      pretend_object.should_receive(:blah)

      @storage.run_task('test', 'run true', :task => lambda { @storage.cmd('true') },
                                            :cleanup => lambda { pretend_object.blah })

      Provision::Storage.cleanup('test')
    end

    it 'performs cleanup tasks in reverse order' do
      pretend_object = double
      pretend_object.should_receive(:blah2).ordered
      pretend_object.should_receive(:blah1).ordered

      @storage.run_task('test', 'run true 1', :task => lambda { @storage.cmd('true') },
                                              :cleanup => lambda { pretend_object.blah1 })

      @storage.run_task('test', 'run true 2', :task => lambda { @storage.cmd('true') },
                                              :cleanup => lambda { pretend_object.blah2 })

      expect do
        @storage.run_task('test', 'fail miserably', :task => lambda do
          @storage.cmd('false')
        end)
      end.to raise_error

      Provision::Storage.cleanup('test')
    end

    it 'removes a cleanup task if the option is set and the task was successful' do
      pretend_object = double
      pretend_object.should_receive(:blah2).ordered
      pretend_object.should_not_receive(:blah1)

      @storage.run_task('test', 'run true 1', :task => lambda { @storage.cmd('true') },
                                              :cleanup => lambda { pretend_object.blah1 })

      @storage.run_task('test', 'run true 2', :task => lambda { @storage.cmd('true') },
                                              :cleanup => lambda { pretend_object.blah2 },
                                              :remove_cleanup => 'run true 1')

      expect do
        @storage.run_task('test', 'fail miserably', :task => lambda { @storage.cmd('false') })
      end.to raise_error

      Provision::Storage.cleanup('test')
    end

    it 'removes multiple cleanup tasks if the option is set and the task was successful' do
      pretend_object = double
      pretend_object.should_receive(:blah4).ordered
      pretend_object.should_receive(:blah1).ordered
      pretend_object.should_not_receive(:blah2)
      pretend_object.should_not_receive(:blah3)

      @storage.run_task('test', 'run true 1', :task => lambda { @storage.cmd('true') },
                                              :cleanup => lambda { pretend_object.blah1 })

      @storage.run_task('test', 'run true 2', :task => lambda { @storage.cmd('true') },
                                              :cleanup => lambda { pretend_object.blah2 })

      @storage.run_task('test', 'run true 3', :task => lambda { @storage.cmd('true') },
                                              :cleanup => lambda { pretend_object.blah3 })

      @storage.run_task('test', 'run true 4', :task => lambda { @storage.cmd('true') },
                                              :cleanup => lambda { pretend_object.blah4 },
                                              :remove_cleanup => ['run true 2', 'run true 3'])

      expect do
        @storage.run_task('test', 'fail miserably', :task => lambda do
          @storage.cmd('false')
        end)
      end.to raise_error

      Provision::Storage.cleanup('test')
    end

    it 'complains if you try to add two cleanup tasks with the same identifier' do
      @storage.run_task('test', 'run true 1', :task => lambda { @storage.cmd('true') },
                                              :cleanup => lambda { pretend_object.blah1 })

      expect do
        @storage.run_task('test', 'run true 1', :task => lambda { @storage.cmd('true') },
                                                :cleanup => lambda { pretend_object.blah1 })
      end.to raise_error
    end
  end
end
