#!/usr/bin/env rspec

require 'arake'
require 'stringio'
require 'tmpdir'

# $ mount
# /dev/disk0s2 on / (hfs, local, journaled)
# devfs on /dev (devfs, local)
# fdesc on /dev (fdesc, union)
# map -hosts on /net (autofs, automounted)
# map auto_home on /home (autofs, automounted)
# 
# $ ruby -e 'p (Dir.glob "/a", File::FNM_CASEFOLD)'
# -e:1:in `glob': invalid byte sequence in US-ASCII (ArgumentError)
#         from -e:1:in `<main>'
# 
# $ ruby --version
# ruby 1.9.2p180 (2011-02-18 revision 30909) [i386-darwin9.8.0]
File::FNM_CASEFOLD = 0

def with_argv(*args, &block)
  original_ARGV = ARGV.dup

  ARGV.clear
  ARGV.push *args

  block.call

  ARGV.clear
  ARGV.push *original_ARGV
end

def with_rakefile(rakefile_content, &block)
  Dir.mktmpdir do |d|
    rakefile = "#{d}/Rakefile"
    File.open rakefile, 'w' do |io|
      io.write rakefile_content
    end
    with_argv *['-f', rakefile] do
      block.call
    end
  end
end

def with_rake_application(rake_application, &block)
  original_Rake_application = Rake.application
  begin
    Rake.application = rake_application
    block.call
  ensure
    Rake.application = original_Rake_application
  end
end

def with_rake(rake_application, rakefile_content, &block)
  with_rakefile rakefile_content do
    with_rake_application rake_application do
      block.call
    end
  end
end

def redirect(stdout = $stdout, &block)
  _stdout = $stdout
  begin
    $stdout = stdout
    block.call
  ensure
    $stdout = _stdout
  end
end

top_level_self = self




describe ARake::CustomRakeAppliation do
  it 'should read rakefiles but should not run any specified targets' do
    rakefile_content = <<-"END"
      p 'outer#{self.object_id}'
      task :default do
        p 'inner#{self.object_id}'
      end
    END
    with_rake ARake::CustomRakeAppliation.new, rakefile_content do
      s = String.new
      redirect (StringIO.new s) do
        Rake.application.run
      end

      (s.index "outer#{self.object_id}").should_not be_nil
      (s.index "inner#{self.object_id}").should be_nil
    end
  end
end




describe ARake::Application do
  def re(s)
    "^#{Regexp.escape s}$"
  end

  it 'should not affect the default Rake.application' do
    oa = Rake.application
    a = ARake::Application.new top_level_self
    with_rake_application a.rake do
      oa.tasks.should be_empty
      a.rake_tasks.should be_empty

      block = Proc.new {}
      top_level_self.instance_eval do
        file 'foo1' => ['bar1', 'baz1'], &block
        file 'foo2' => ['bar2', 'baz2'], &block
      end

      oa.tasks.should be_empty
      a.rake_tasks.should_not be_empty
    end
  end

  it 'should be able to refer tasks' do
    a = ARake::Application.new top_level_self
    with_rake_application a.rake do
      a.rake_tasks.should be_empty

      block = Proc.new {}
      top_level_self.instance_eval do
        file 'foo1' => ['bar1', 'baz1'], &block
        file 'foo2' => ['bar2', 'baz2'], &block
      end

      a.rake_tasks.should_not be_empty
      a.rake_tasks[0].to_s.should eql 'foo1'
      a.rake_tasks[0].prerequisites.should eql ['bar1', 'baz1']
      a.rake_tasks[0].actions.should eql [block]
      a.rake_tasks[1].to_s.should eql 'foo2'
      a.rake_tasks[1].prerequisites.should eql ['bar2', 'baz2']
      a.rake_tasks[1].actions.should eql [block]
    end
  end

  it 'should define a watch rule for each dependent' do
    a = ARake::Application.new top_level_self
    with_rake_application a.rake do
      a.rake_tasks.should be_empty
      a.watchr_rules.should be_empty

      block = Proc.new {}
      top_level_self.instance_eval do
        file 'foo1' => ['bar1', 'baz1'], &block
        file 'foo2' => ['bar2', 'baz2'], &block
      end
      a.watchr_script.parse!

      a.rake_tasks.should_not be_empty
      a.watchr_rules.should_not be_empty
      a.watchr_rules[0].pattern.should eql re('bar1')
      a.watchr_rules[1].pattern.should eql re('baz1')
      a.watchr_rules[2].pattern.should eql re('bar2')
      a.watchr_rules[3].pattern.should eql re('baz2')
    end
  end

  it 'should invoke a rake task with proper parameters' do
    a = ARake::Application.new top_level_self
    with_rake_application a.rake do
      passed_task = nil
      block = Proc.new {|task| passed_task = task}
      top_level_self.instance_eval do
        file 'foo' => 'bar', &block
      end
      a.watchr_script.parse!
      r = a.watchr_rules[0]

      r.pattern.should eql re('bar')
      passed_task.should be_nil

      r.action.call
      t = a.rake_tasks[1]

      t.to_s.should eql 'foo'
      passed_task.should equal t
    end
  end

  it 'should execute rake tasks even if they are already executed before' do
    a = ARake::Application.new top_level_self
    with_rake_application a.rake do
      call_count = 0
      block = Proc.new {call_count += 1}
      top_level_self.instance_eval do
        task :dependent
        task :target => :dependent, &block
      end
      a.watchr_script.parse!
      r = a.watchr_rules[0]

      r.pattern.should eql re(:dependent)
      call_count.should eql 0

      r.action.call

      call_count.should eql 1

      r.action.call

      call_count.should eql 2
    end
  end
end

__END__
