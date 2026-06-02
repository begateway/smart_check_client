# frozen_string_literal: true

require_relative "smart_check/version"
require "logger"
require "active_support"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/object/blank"
require "faraday"
require "faraday_middleware"

module SmartCheck
  autoload :Client, "smart_check/client"
  autoload :Response, "smart_check/response"
end
