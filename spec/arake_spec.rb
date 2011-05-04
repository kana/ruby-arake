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

__END__
