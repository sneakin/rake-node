require 'webrick/https'
require 'webrick/ssl'
require 'rake-node/http/ssl'

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
    
    def self.open_ca_cert(bits, cn, cert_path, key_path)
      ca_key = nil
      ca_cert = nil

      if File.exists?(cert_path)
        ca_cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
        ca_key = OpenSSL::PKey::RSA.new(File.read(key_path))
      else
        $stderr.puts("Generating CA certificate: #{cn.inspect}")
        ca_cert, ca_key = WEBrick::Utils.create_self_signed_cert(bits, [["CN", cn]], "The CA Cert")
        $stderr.puts("  Writing CA key to: #{key_path}")
        File.open(key_path, 'wb') { |f| f.write(ca_key) }
        $stderr.puts("  Writing CA cert to: #{cert_path}")
        File.open(cert_path, 'wb') { |f| f.write(ca_cert) }
        $stderr.puts
        $stderr.puts("YOU WILL NEED TO LOAD #{cert_path.inspect} INTO THE CLIENT BROWSER.")
        $stderr.puts
      end
      return [ ca_cert, ca_key ]
    end

    ##
    # opts[:ca] :: The CA's certificate and key in an Array.
    # 
    def self.open_certificate(base_path, opts = {})
      key_path = base_path.to_s + ".key"
      cert_path = base_path.to_s + ".crt"
      
      if File.exists?(key_path)
        key = OpenSSL::PKey::RSA.new(File.read(key_path))
        cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
      else
        domains = opts[:domains]
        domains = domains.split(',') if domains.kind_of?(String)
        domains = [ WEBrick::Utils.getservername ] if domains.empty?
        domain = domains.first

        ip = (opts[:ip] || '').split(',')
        san = opts.fetch(:san) { san_string(domains, ip) }
        cn = [["CN", domain]]

        cert, key = WEBrick::Utils.create_self_signed_cert(4096, cn, "",
                                                           san: san,
                                                           ca: opts.fetch(:ca))
        File.open(key_path, 'w') do |f|
          f.puts(key.export)
        end
        File.open(cert_path, 'w') do |f|
          f.puts(cert.to_pem)
        end
      end

      return cert, key
    end

    ##
    # opts[:ca_cname] :: Domain or CName to use for the generated certificate authority certificate.
    # opts[:ca] :: Pathname less the extension for the certificate authority certificate and key.
    # opts[:IP] :: IP address to use as an subjectAltName
    # opts[:Domain] :: Comma separated list of domain names. First is used for the CName.
    # 
    def self.run(opts)
      root = opts.fetch(:DocumentRoot)
      $stderr.puts("Serving files from #{root}")
      ssl_opts = {}

      if opts[:SSLCertPrefix]
        domains = (opts[:Domain] || '').split(',')
        domains = [ WEBrick::Utils.getservername ] if domains.empty?
        domain = domains.first

        ca_cname = opts[:ca_cname] || domain
        ca_base = opts[:ca] || 'ssl_ca'
        ca_cert_path = ca_base.to_s + ".crt"
        ca_cert, ca_key = open_ca_cert(4096, ca_cname, ca_cert_path, ca_base.to_s + ".key")

        cert, key = open_certificate(opts.fetch(:SSLCertPrefix),
                                     domains: domains,
                                     ip: opts.fetch(:IP, nil),
                                     ca: [ ca_cert, ca_key ])

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
