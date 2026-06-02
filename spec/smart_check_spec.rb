# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SmartCheck do
  it 'has a version number' do
    expect(SmartCheck::VERSION).not_to be_nil
  end
end
