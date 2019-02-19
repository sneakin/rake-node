task :test => [ 'test/Rakefile' ] do
  sh("cd test && rake verify && rake clean")
end

task :default => :test
