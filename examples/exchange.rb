# frozen_string_literal: true

# Minimal example. Run with:
#   UNIRATE_API_KEY=your-key ruby examples/exchange.rb
#
# Requires the `money` gem and this gem on the load path.

require "money"
require "money/bank/uni_rate"

# UniRate is the rate source for the global default bank.
Money.default_bank = Money::Bank::UniRate.new(
  api_key: ENV.fetch("UNIRATE_API_KEY"),
  ttl_in_seconds: 3600 # re-fetch the snapshot at most once an hour
)

usd = Money.new(100_00, "USD") # $100.00
puts "#{usd.format} = #{usd.exchange_to('EUR').format}"
puts "#{usd.format} = #{usd.exchange_to('GBP').format}"
puts "#{usd.format} = #{usd.exchange_to('JPY').format}"

# Cross-rates are derived from the single USD snapshot.
eur = Money.new(50_00, "EUR")
puts "#{eur.format} = #{eur.exchange_to('GBP').format}"
