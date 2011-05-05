#!/usr/bin/env ruby

require 'rake'
require 'watchr'




module ARake
  class Application
    attr_accessor :rake

    def initialize(top_level_self)
      @top_level_self = top_level_self
      @rake = CustomRakeAppliation.new
      @_watchr = nil
      @_watchr_script = nil
    end

    def watchr
      @_watchr ||= create_custom_watchr
    end

    def watchr_script
      @_watchr_script ||= create_custom_watchr_script
    end

    def watchr_rules
      watchr_script.rules
    end

    def create_custom_watchr
      Watchr::Controller.new(watchr_script, Watchr.handler.new)
    end

    def create_custom_watchr_script
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
      s
    end

    def run
      original_Rake_application = Rake.application
      begin
        Rake.application = @rake

        Rake.application.run
        watchr.run
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
