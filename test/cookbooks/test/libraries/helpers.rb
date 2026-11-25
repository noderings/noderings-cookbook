# frozen_string_literal: true

require 'base64'
require 'openssl'

module NodeRingsTest
  module_function

  # An OpenSSH public key for a throwaway RSA key. NodeRings stores each key
  # once, so every test run uses its own; it is kept in key_dir so the second
  # converge (the idempotency check) sees the same key.
  def public_key(dir, id)
    path = ::File.join(dir, "#{id}.pub")
    return ::File.read(path).strip if ::File.exist?(path)

    rsa = OpenSSL::PKey::RSA.generate(2048)
    data = string('ssh-rsa') + mpint(rsa.e.to_s(2)) + mpint(rsa.n.to_s(2))
    key = "ssh-rsa #{Base64.strict_encode64(data)} #{id}"
    ::FileUtils.mkdir_p(dir)
    ::File.write(path, key)
    key
  end

  def string(value)
    [value.bytesize].pack('N') + value
  end

  def mpint(bytes)
    bytes = "\0#{bytes}" if bytes.getbyte(0) & 0x80 != 0
    string(bytes)
  end

  def names(node)
    id = node['noderings_test']['id']
    {
      key: "#{id}-key",
      zone: "#{id}.#{node['noderings_test']['domain']}",
      ruleset: "#{id}-web",
      vm: "#{id}-vm",
    }
  end
end
