require 'rbconfig'
require 'pathname'
require 'fileutils'
require 'shellwords'

ROOT ||= Pathname.new(__FILE__).parent.parent

NODE_DELIM = if RbConfig::CONFIG['EXEEXT'] == '.exe'
               ';'
             else
               ':'
             end

NODE_PATH ||= [ ROOT.join('bacaw', 'js', 'lib').to_s,
                ROOT.join('bacaw', 'www').to_s,
                ROOT.join('the-bacaw').to_s
              ].join(NODE_DELIM)

def html_file(opts, &block)
  opts.each do |file, src|
    file(file => src) do |t|
      FileUtils.copy(t.sources[0], t.name)
      block.call(t) if block
    end
  end
end

class BrowserifyRunner
  class << self
    include Rake::DSL
    
    @@js_deps = Hash.new

    def root
      @@root || ROOT
    end

    def root=(v)
      @@root = v.expand_path
    end

    def set_env!
      ENV['NODE_PATH'] = NODE_PATH
    end
    
    def js_deps_for(file)
      set_env!
      @@js_deps[file] ||= `browserify --list #{Shellwords.escape(file)}`.
        each_line.collect { |p|
        Pathname.new(p.chomp).expand_path.to_s
      }
    end

    def bundle(opts)
      set_env!
      
      opts.each do |target, src|
        deps = js_deps_for(src.first)
        file target => deps do |t|
          sh("browserify #{Shellwords.escape(src.first)} -o #{Shellwords.escape(t.name)}")
        end
      end
    end
  end
end
