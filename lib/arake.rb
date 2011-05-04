#!/usr/bin/env ruby

require 'rake'
require 'watchr'




class ARake
  attr_accessor :accumulated_args

  def initialize(top_level_self)
    @top_level_self = top_level_self
    @accumulated_args = []

    hook_task_definition
  end

  def hook_task_definition
    a = self
    (class << @top_level_self; self; end).class_eval do
      include Rake::TaskManager

      # FIXME: How about other rake tasks?
      define_method :file do |*args, &block|
        super *args, &block
        a.accumulate_args *resolve_args(args), &block
      end
    end
  end

  def accumulate_args(*args, &block)
    @accumulated_args.push [*args, block]
  end

  def create_custom_watchr
    a = self
    s = Watchr::Script.new
    (class << s; self; end).class_eval do
      define_method :parse! do
        @ec.instance_eval do
          a.accumulated_args.each do |pattern, arg_names, deps, block|
            p deps
            deps.each do |d|
              watch "^#{Regexp.escape d}$", &block
            end
          end
        end
      end
    end
    Watchr::Controller.new(s, Watchr.handler.new)
  end

  def load_rakefiles
    RakeApplicationWrapper.new.run
  end

  def run
    load_rakefiles
    watchr = create_custom_watchr
    watchr.run
  end
end

class RakeApplicationWrapper < Rake::Application
  def run
    standard_exception_handling do
      init
      load_rakefile
      # Don't run top_level at first.  Because all tasks are automatically run
      # whenever dependents are updated.
    end
  end
end




__END__
