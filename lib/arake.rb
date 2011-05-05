#!/usr/bin/env ruby

require 'rake'
require 'watchr'




module ARake
  class Application
    def initialize(top_level_self)
      @_rake = nil
      @_watchr = nil
      @_watchr_script = nil
      @top_level_self = top_level_self
    end

    def run
      original_Rake_application = Rake.application
      begin
        Rake.application = rake

        Rake.application.run
        watchr.run
      ensure
        Rake.application = original_Rake_application
      end
    end

    # Misc.

    def rake
      @_rake ||= CustomRakeAppliation.new
    end

    def rake_tasks
      rake.tasks
    end

    def watchr
      @_watchr ||= _create_custom_watchr
    end

    def _create_custom_watchr
      Watchr::Controller.new(watchr_script, Watchr.handler.new)
    end

    def watchr_rules
      watchr_script.rules
    end

    def watchr_script
      @_watchr_script ||= _create_custom_watchr_script
    end

    def _create_custom_watchr_script
      a = self
      s = Watchr::Script.new
      (class << s; self; end).class_eval do
        define_method :parse! do
          @ec.instance_eval do
            a.rake_tasks.each do |t|
              t.prerequisites.each do |p|
                watch "^#{Regexp.escape p}$" do
                  a.rake.reenable_all_tasks
                  t.invoke
                end
              end
            end
          end
        end
      end
      s
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

    def reenable_all_tasks
      tasks.each do |t|
        t.reenable
      end
    end
  end
end




__END__
