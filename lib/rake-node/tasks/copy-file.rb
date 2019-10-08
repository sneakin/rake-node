module RakeNode
  module CopyFile
    def copy_task(opts)
      opts.each do |dest, src|
        file dest => [ *src, File.dirname(dest) ] do |t|
          FileUtils.copy(t.sources[0], t.name)
        end
      end
    end
  end
end
