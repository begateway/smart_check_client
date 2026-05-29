# frozen_string_literal: true

require_relative "lib/smart_check/version"

Gem::Specification.new do |spec|
  spec.name = "smart_check"
  spec.version = SmartCheck::VERSION
  spec.authors = ["Dmitry Melkunas"]
  spec.email = ["dmitry.melkunas@ecomcharge.com"]

  spec.summary = "Smart Check client for communication with the Smart Check service"
  spec.description = "Smart Check client for communication with the Smart Check service"
  spec.homepage = "https://github.com/begateway/smart_check_client"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/begateway/smart_check_client"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency("activesupport", [">= 0"])
  spec.add_runtime_dependency("faraday", [">= 0"])
  spec.add_runtime_dependency("faraday_middleware", [">= 0"])

  spec.add_development_dependency("bundler", ["~> 2.4.13"])
  spec.add_development_dependency("rake", ["~> 12.3.3"])
  spec.add_development_dependency("rspec", [">= 0"])
  spec.add_development_dependency("pry", [">= 0"])
  spec.add_development_dependency("webmock", [">= 0"])
end
