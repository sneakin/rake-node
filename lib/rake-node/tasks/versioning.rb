module RakeNode
  module Versioning
    def read_version(path)
      parse_version(File.read(path))
    end

    def parse_version(v)
      p = v.match(/(\d+)\.(\d+)\.(\d+)/)
      if p
        [ p[1], p[2], p[3] ].collect(&:to_i)
      else
        [ 0, 0, 0 ]
      end
    end

    def version_string(v)
      v.collect(&:to_s).join('.')
    end

    def write_version_io(v, io)
      io.puts(version_string(v))
    end

    def write_version(v, path)
      File.open(path, 'w') do |f|
        write_version_io(v, f)
      end
    end

    def commit_version(version_path)
      v = version_string(read_version(version_path))
      sh("git commit -m 'Bumped version to #{v}.' #{version_path}")
    end

    def generate_versioning(version_path)
      namespace :version do
        task :echo do
          write_version_io(read_version(version_path), $stdout)
        end

        task :commit do
          commit_version(version_path)
        end

        namespace :bump do
          { major: 0, minor: 1, release: 2 }.each do |name, index|
            desc "Bump the #{name} version number in #{version_path}."
            task name do
              v = read_version(version_path)
              v[index] += 1
              write_version(v, version_path)
              write_version_io(v, $stdout)
              commit_version(version_path)
            end
          end
        end
      end
      
    end
  end
end
