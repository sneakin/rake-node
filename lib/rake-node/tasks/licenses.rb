require('json')

module RakeNode
  module Licenses
    class LicenseInfo
      attr_accessor :name, :version, :licenses, :licenseFile, :path, :url, :publisher, :repository

      def initialize(name, hash)
        m = name.match(/(.*)@(\d+(\.\d+)*)/)
        if m
          @name = m[1]
          @version = m[2]
        else
          @name = name
          @version = nil
        end
        @licenses = hash['licenses'].split(',')
        @licenseFile = hash['licenseFile']
        @repository = hash['repository']
        @url = hash['url']
        @path = hash['path']
        @publisher = hash['publisher']
      end

      def license_text
        @license_text ||= File.read(@licenseFile)
      end

      def license_standalone?
        @licenseFile =~ /(LICENSE|COPYING)/
      end

      def self.[](entries, exclude = [])
        entries.reduce(Hash.new) do |h, (name, info)|
          e = self.new(name, info)
          if !exclude.include?(e.name)
            h[e.name] = e
          end
          h
        end
      end
    end

    def license_json_file(path)
      directory File.dirname(path)
      
      file path => [ 'package.json', File.dirname(path) ] do |t|
        sh("license-checker --json > #{t.name}")
      end
    end
    
    def self.load(path, exclude = [])
      LicenseInfo[JSON.load(File.read(path)), exclude]
    end
  end
end
