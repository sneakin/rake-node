# frozen_string_literal: false
#
# ssl.rb -- SSL/TLS enhancement for GenericServer
#
# Copyright (c) 2003 GOTOU Yuuzou All rights reserved.
#
# 2019 Nolan Eakins sneakin@semanticgap.com: CA generation and signing added
#
# $Id$

require 'webrick'
require 'openssl'

module WEBrick
  module Utils
    ##
    # Creates a self-signed certificate with the given number of +bits+,
    # the issuer +cn+ and a +comment+ to be stored in the certificate.

    def create_self_signed_cert(bits, cn, comment, opts = {})
      ca_cert, ca_key = opts[:ca]

      rsa = OpenSSL::PKey::RSA.new(bits){|p, n|
        case p
        when 0; $stderr.putc "."  # BN_generate_prime
        when 1; $stderr.putc "+"  # BN_generate_prime
        when 2; $stderr.putc "*"  # searching good prime,
                                  # n = #of try,
                                  # but also data from BN_generate_prime
        when 3; $stderr.putc "\n" # found good prime, n==0 - p, n==1 - q,
                                  # but also data from BN_generate_prime
        else;   $stderr.putc "*"  # BN_generate_prime
        end
      }
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = rand(65535)
      name = (cn.kind_of? String) ? OpenSSL::X509::Name.parse(cn)
                                  : OpenSSL::X509::Name.new(cn)
      cert.subject = name
      cert.not_before = Time.now - 48*60*60
      cert.not_after = Time.now + (365*24*60*60)
      cert.public_key = rsa.public_key

      ef = OpenSSL::X509::ExtensionFactory.new(nil,cert)

      cert.extensions = [
        ef.create_extension("keyUsage", "keyEncipherment, dataEncipherment, digitalSignature, cRLSign, keyCertSign"),
        ef.create_extension("subjectKeyIdentifier", "hash"),
        ef.create_extension("extendedKeyUsage", "serverAuth"),
        ef.create_extension("nsComment", comment)
      ]

      if ca_key
        cert.issuer = ca_cert.subject
        cert.add_extension(ef.create_extension("basicConstraints","CA:FALSE"))
        ef.issuer_certificate = ca_cert
        signing_key = ca_key
      else
        cert.issuer = name
        cert.add_extension(ef.create_extension("basicConstraints","CA:TRUE"))
        ef.issuer_certificate = cert
        signing_key = rsa
      end

      cert.add_extension(ef.create_extension("subjectAltName", opts.fetch(:san))) if opts[:san]
      aki = ef.create_extension("authorityKeyIdentifier",
                                "keyid:always,issuer:always")
      cert.add_extension(aki)
      cert.sign(signing_key, OpenSSL::Digest::SHA256.new)
      return [ cert, rsa ]
    end
    module_function :create_self_signed_cert
  end
end
