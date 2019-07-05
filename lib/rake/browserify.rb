require 'rbconfig'
require 'pathname'
require 'fileutils'
require 'shellwords'
require 'yaml'

ROOT ||= Pathname.new(__FILE__).parent.parent.parent

NODE_DELIM = if RbConfig::CONFIG['EXEEXT'] == '.exe'
               ';'
             else
               ':'
             end

NODE_PATH ||= []
NODE_PATH << ROOT.glob('node_modules/*/lib').collect(&:to_s)

def html_file(opts, &block)
  opts.each do |file, src|
    file(file => src) do |t|
      FileUtils.copy(t.sources[0], t.name)
      block.call(t) if block
    end
  end
end

class BrowserifyRunner
  if ENV['ENV'] == 'production'
    DefaultOptions = {
      :plugins => nil,
      :transforms => [ 'brfs' ],
      :globals => [ 'uglifyify' ]
    }
  else
    DefaultOptions = {
      :plugins => nil,
      :transforms => [ 'brfs' ]
    }
  end

  class << self
    include Rake::DSL
    
    @@js_deps = Hash.new
    @@root = ROOT

    def load!(path = File.join(root, '.deps.rake'))
      @@js_deps = YAML.load(File.read(path))
      $stderr.puts("Loaded deps from #{path}");
    rescue
      $stderr.puts("Error #{$!} loading deps from #{path}");
    end

    def hook_exit!(path = File.join(root, '.deps.rake'))
      at_exit do
        BrowserifyRunner.save_deps!(path)
      end
    end
    
    def save_deps!(path)
      File.open(path, 'w') do |f|
        $stderr.puts("Saving deps to #{path}")
        f.write(BrowserifyRunner.js_deps.to_yaml)
      end
    end
    
    def js_deps
      @@js_deps
    end

    def root
      @@root || ROOT
    end

    def root=(v)
      @@root = v.expand_path
    end

    def set_env!
      ENV['NODE_PATH'] = NODE_PATH.flatten.join(NODE_DELIM)
    end
    
    def js_deps_for(file)
      set_env!
      @@js_deps[file] ||= `browserify --list #{Shellwords.escape(file)}`.
        each_line.collect { |p|
        Pathname.new(p.chomp).expand_path.to_s
      }
    end

    def collect_arguments(opt, values)
      if values && !values.empty?
        values.each.reduce(Array.new) do |out, v|
          out << opt << Shellwords.escape(v)
          out
        end
      end
    end
    
    def bundle(targets, opts = nil)
      opts = DefaultOptions.merge(opts || {})

      args = []
      args << collect_arguments("-p", opts[:plugins])
      args << collect_arguments("-t", opts[:transforms])
      args << collect_arguments("-g", opts[:globals])
      args = args.flatten.join(' ')
      
      set_env!
      
      targets.each do |target, src|
        deps = js_deps_for(src.first)
        file target => deps do |t|
          sh("browserify #{args} #{Shellwords.escape(src.first)} -o #{Shellwords.escape(t.name)}")
        end
      end
    end
  end

  module Tasks
    include Rake::DSL

    def self.included(mod)
      BrowserifyRunner.load!
      BrowserifyRunner.hook_exit!
    end
  end
end

include BrowserifyRunner::Tasks
