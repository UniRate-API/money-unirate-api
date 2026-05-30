# frozen_string_literal: true

# Standalone version constant. It deliberately lives in its own top-level
# module so the gemspec can read the version *without* loading the `money`
# gem: `Money` is a class there, and reopening it as a module at gem-build
# time (before `money` is installed) would raise a TypeError.
module MoneyUniRateApi
  VERSION = "0.1.0"
end
