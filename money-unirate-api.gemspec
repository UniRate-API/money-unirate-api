# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "money/bank/uni_rate/version"

Gem::Specification.new do |spec|
  spec.name          = "money-unirate-api"
  spec.version       = MoneyUniRateApi::VERSION
  spec.authors       = ["Unirate Team"]
  spec.email         = ["admin@unirateapi.com"]

  spec.summary       = "UniRate API exchange-rate bank for the money gem."
  spec.description   = "A Money::Bank implementation backed by the UniRate API " \
                       "(https://unirateapi.com) — free currency exchange rates " \
                       "for RubyMoney. Fetches one base snapshot and derives all " \
                       "cross-rates, with optional TTL-based refresh."
  spec.homepage      = "https://github.com/UniRate-API/money-unirate-api"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://unirateapi.com",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    "money-unirate-api.gemspec"
  ]
  spec.require_paths = ["lib"]

  spec.add_dependency "money", ">= 6.13", "< 8"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "webmock", "~> 3.19"
end
