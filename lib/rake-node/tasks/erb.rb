require('erb')

module RakeNode
  module ERB
    def erb_file(opts, &bindings)
      file opts do |t|
        File.open(t.name, 'w') do |f|
          tmpl = File.read(t.sources[0])
          erb = ::ERB.new(tmpl, nil, '<>')
          data = nil
          if bindings
            bindings.call(t)
            data = bindings.binding
          end
          f.write(erb.result, data)
        end
      end
    end    
  end
end
