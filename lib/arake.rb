#!/usr/bin/env ruby

require 'rake'
require 'watchr'




module ARake
  class Application
    attr_accessor :rake

    def initialize(top_level_self)
      @top_level_self = top_level_self
      @rake = CustomRakeAppliation.new
    end

    def create_custom_watchr
      a = self
      s = Watchr::Script.new
      (class << s; self; end).class_eval do
        define_method :parse! do
          @ec.instance_eval do
            a.rake.tasks.each do |t|
              t.prerequisites.each do |p|
                watch "^#{Regexp.escape p}$" do
                  t.invoke
                end
              end
            end
          end
        end
      end
      Watchr::Controller.new(s, Watchr.handler.new)
    end

    def run
      original_Rake_application = Rake.application
      begin
        Rake.application = @rake

        Rake.application.run
        create_custom_watchr.run
      ensure
        Rake.application = original_Rake_application
      end
    end
  end

  class CustomRakeAppliation < Rake::Application
    def run
      standard_exception_handling do
        init
        load_rakefile
        # Don't run top_level at first.  Because all tasks are automatically
        # run whenever dependents are updated.
      end
    end
  end
end




__END__
