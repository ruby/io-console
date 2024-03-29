task :force

Rake::Task[:force].tap do |task|
  task.instance_eval {
    def (@timestamp = Object.new).>(other)
      true
    end
  }
  class << task
    attr_reader :timestamp
  end
end
