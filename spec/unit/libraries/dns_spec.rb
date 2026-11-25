# frozen_string_literal: true

require 'spec_helper'
load_noderings_libraries

describe NodeRingsCookbook::DNS do
  it 'makes names relative to the zone' do
    expect(described_class.relative_name('www.Example.com.', 'example.com')).to eq 'www'
    expect(described_class.relative_name('example.com', 'example.com.')).to eq '@'
    expect(described_class.relative_name('', 'example.com')).to eq '@'
    expect(described_class.relative_name('a.b', 'example.com')).to eq 'a.b'
  end

  it 'validates values by type' do
    expect(described_class.validate_values('A', ['192.0.2.1'])).to be_nil
    expect(described_class.validate_values('A', ['2001:db8::1'])).to match(/not an IPv4/)
    expect(described_class.validate_values('AAAA', ['::ffff:192.0.2.1'])).to match(/not an IPv6/)
    expect(described_class.validate_values('CNAME', %w(a. b.))).to match(/exactly one/)
    expect(described_class.validate_values('ALIAS', ['192.0.2.1'])).to match(/hostname/)
    expect(described_class.validate_values('TXT', [])).to match(/at least one/)
  end

  it 'compares values the way the API stores them' do
    expect(described_class.same_values?('CNAME', ['WWW.example.net'], ['www.example.net.'])).to be true
    expect(described_class.same_values?('MX', ['10 MX.example.net'], ['10 mx.example.net.'])).to be true
    expect(described_class.same_values?('A', %w(192.0.2.2 192.0.2.1), %w(192.0.2.1 192.0.2.2))).to be true
    expect(described_class.same_values?('TXT', ['Hello'], ['hello'])).to be false
  end

  it 'quotes and splits long TXT values on character boundaries' do
    value = "#{'é' * 200}\"q\" \\ end"
    quoted = described_class.quote_txt(value)
    expect(quoted).to start_with('"')
    quoted.scan(/"((?:[^"\\]|\\.)*)"/).each { |(part)| expect(part.gsub(/\\(.)/, '\1').bytesize).to be <= 255 }
    expect(described_class.unquote_txt(quoted)).to eq value
  end
end
