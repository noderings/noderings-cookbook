# frozen_string_literal: true

require 'chefspec'
require 'chefspec/policyfile'
require_relative 'support/fake_noderings'

# The cookbook's libraries read these to find the API. Chef loads the
# libraries during each converge; declaring the accessors here lets tests set
# them first.
module NodeRingsCookbook
  class << self
    attr_accessor :transport, :sleeper
  end
end

# Loads the cookbook libraries for tests that use them without a Chef run.
def load_noderings_libraries
  Dir[File.expand_path('../libraries/*.rb', __dir__)].sort.each { |f| require f }
end

RSpec.configure do |config|
  config.color = true
  config.formatter = :documentation
  config.log_level = :error

  config.before do
    @fake = FakeNodeRings.new
    NodeRingsCookbook.transport = @fake
    NodeRingsCookbook.sleeper = ->(_s) {}
    ENV['NODERINGS_TOKEN'] = 'test-token'
  end

  config.after do
    ENV.delete('NODERINGS_TOKEN')
  end
end
