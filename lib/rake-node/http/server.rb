# require 'rake-node/webrick'
require 'webrick/https'
require 'webrick/ssl'

module RakeNode
  module HTTP
    class Server < WEBrick::HTTPServer
      def initialize(*args)
        super
        @domain = WEBrick::Utils.getservername
      end
      
      def service(req, res)
        super
        res['Access-Control-Allow-Origin'] = '*'
        res['Access-Control-Request-Method'] = '*'
        res['Cache-Control'] = 'no-cache,max-age=0'
        res['ServerName'] = @domain
      end
    end

    def self.san_string(domains, ips)
      [ domains.collect { |d| "DNS:#{d}" },
        ips.collect { |a| "IP:#{a}" }
      ].flatten.join(',')
    end
    
    def self.open_certificate(base_path, opts = {})
      ca_cert = opts.fetch(:ca_cert, nil)
      ca_key = opts.fetch(:ca_key, nil)

      key_path = base_path.to_s + ".key"
      cert_path = base_path.to_s + ".crt"
      
      if File.exists?(key_path)
        key = OpenSSL::PKey::RSA.new(File.read(key_path))
        cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
      else
        domains = opts.fetch(:domains, '').split(',')
        domains = [ WEBrick::Utils.getservername ] if domains.empty?
        domain = domains.first
        ip = (opts[:ip] || '').split(',')
        san = opts.fetch(:san) { san_string(domains, ip) }
        cn = [["CN", domain]]

        cert, key = WEBrick::Utils.create_self_signed_cert(4096, cn, "",
                                                           san: san,
                                                           ca_cert: ca_cert,
                                                           ca_key: ca_key)
        File.open(key_path, 'w') do |f|
          f.puts(key.export)
        end
        File.open(cert_path, 'w') do |f|
          f.puts(cert.to_pem)
        end
      end

      return cert, key
    end

    def self.run(opts)
      root = opts.fetch(:DocumentRoot)
      $stderr.puts("Serving files from #{root}")
      ssl_opts = {}
      if opts[:SSLCertPrefix]
        cert, key = open_certificate(opts.fetch(:SSLCertPrefix),
                                     domains: opts.fetch(:Domain, nil),
                                     ip: opts.fetch(:IP, nil))

        ssl_opts = {
          SSLEnable: true,
          SSLVerifyClient: OpenSSL::SSL::VERIFY_NONE,
          SSLCertificate: cert,
          SSLPrivateKey: key
        }
      end
      
      s = Server.new({ Port: opts.fetch(:Port, 9090),
                        DocumentRoot: opts.fetch(:DocumentRoot)
                      }.merge(ssl_opts))
      trap('INT') { s.shutdown }
      s.start
    end
  end
end
