# frozen_string_literal: true

require 'base64'
require 'smart_check'
require 'webmock/rspec'

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

WebMock.disable_net_connect!(allow_localhost: true)
