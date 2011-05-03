Gem::Specification.new do |s|
  s.name = 'arake'
  s.version = `git describe --always --tags --dirty`
  s.summary = 'Run rake automatically whenever any dependent is updated.'

  s.authors = ['Kana Natsuno']
  s.email = ['kana@whileimautomaton.n3t']
  s.homepage = 'http://github.com/kana/ruby-arake'

  s.required_ruby_version = '>= 1.9.2'
  s.required_rubygems_version = '>= 1.6.2'

  s.files = `git ls-files`.split("\n")
  s.executables = s.files.select{|f| f =~ /^bin/}.map{|f| f.sub /^bin/, ''}
  s.add_runtime_dependency 'rake', '>= 0.8.7'
  s.add_runtime_dependency 'watchr', '>= 0.7'
  s.add_development_dependency 'rspec', '>= 2.5.1'
end
