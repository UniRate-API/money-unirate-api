# frozen_string_literal: true

require "bigdecimal"
require "json"
require "net/http"
require "uri"

require "money"
require_relative "uni_rate/version"

class Money
  module Bank
    # Raised for any UniRate-specific failure: a network problem, an auth
    # error, a Pro-gated endpoint, or an unexpected response shape.
    class UniRateError < StandardError; end

    # A {Money::Bank} implementation backed by the UniRate API
    # (https://unirateapi.com).
    #
    # It fetches a single-base rate snapshot from `GET /api/rates` and derives
    # every cross-rate from it on demand, so one HTTP call covers all currency
    # pairs. Derived cross-rates are computed per call (not cached in the
    # store) so a TTL refresh can never serve a stale pair.
    #
    #   require "money/bank/uni_rate"
    #
    #   Money.default_bank = Money::Bank::UniRate.new(api_key: ENV["UNIRATE_API_KEY"])
    #   Money.new(100_00, "USD").exchange_to("EUR")  # => #<Money fractional:9200 currency:EUR>
    #
    # Rates are fetched lazily on the first conversion and re-fetched once
    # +ttl_in_seconds+ has elapsed. Leave +ttl_in_seconds+ as +nil+ to fetch
    # exactly once and cache for the life of the object; call {#flush_rates}
    # to force a refresh on the next conversion.
    class UniRate < Money::Bank::VariableExchange
      DEFAULT_BASE_URL = "https://api.unirateapi.com"
      DEFAULT_BASE_CURRENCY = "USD"
      DEFAULT_TIMEOUT = 30

      attr_reader :base_currency, :rates_updated_at
      attr_accessor :ttl_in_seconds

      # @param api_key [String] UniRate API key (falls back to ENV["UNIRATE_API_KEY"])
      # @param base_currency [String] currency the snapshot is fetched against
      # @param ttl_in_seconds [Integer, nil] re-fetch interval; nil = fetch once
      # @param base_url [String] base URL override (for testing)
      # @param timeout [Integer, Float] per-request timeout in seconds
      # @param store [Money::RatesStore::Memory] rate store (defaults to in-memory)
      def initialize(api_key: ENV.fetch("UNIRATE_API_KEY", nil),
                     base_currency: DEFAULT_BASE_CURRENCY,
                     ttl_in_seconds: nil,
                     base_url: DEFAULT_BASE_URL,
                     timeout: DEFAULT_TIMEOUT,
                     store: Money::RatesStore::Memory.new,
                     &block)
        if api_key.nil? || api_key.to_s.empty?
          raise ArgumentError, "api_key is required (pass api_key: or set UNIRATE_API_KEY)"
        end

        @api_key = api_key
        @base_currency = base_currency.to_s.upcase
        @ttl_in_seconds = ttl_in_seconds
        @base_url = base_url
        @timeout = timeout
        @rates_updated_at = nil
        super(store, &block)
      end

      # Fetch the latest snapshot and store base->currency rates. Returns the
      # raw { "EUR" => BigDecimal, ... } map. Called lazily on the first
      # conversion; safe to call manually to warm the cache.
      def update_rates
        rates = fetch_rates
        add_rate(base_currency, base_currency, 1)
        rates.each { |code, value| add_rate(base_currency, code, value) }
        @rates_updated_at = Time.now
        rates
      end

      # True when rates have never been fetched, or +ttl_in_seconds+ elapsed.
      def expired?
        return true if rates_updated_at.nil?
        return false if ttl_in_seconds.nil?

        Time.now - rates_updated_at > ttl_in_seconds
      end

      # Exchange rate from +from+ to +to+, deriving cross-rates from the
      # single-base snapshot. Auto-refreshes when {#expired?}.
      #
      # @return [BigDecimal]
      def get_rate(from, to, _opts = {})
        from_iso = Money::Currency.wrap(from).iso_code
        to_iso = Money::Currency.wrap(to).iso_code

        update_rates if expired?
        return BigDecimal(1) if from_iso == to_iso

        base_rate(to_iso) / base_rate(from_iso)
      end

      # Force a refresh on the next conversion (does not hit the network now).
      def flush_rates
        @rates_updated_at = nil
        self
      end

      private

      # base_currency -> iso rate (1 for the base itself). Raises if absent.
      def base_rate(iso)
        return BigDecimal(1) if iso == base_currency

        rate = store.get_rate(base_currency, iso)
        raise UniRateError, "No UniRate rate available for #{base_currency}->#{iso}" if rate.nil?

        rate
      end

      def fetch_rates
        body = http_get("/api/rates", "from" => base_currency)
        rates = body["rates"]
        raise UniRateError, 'Unexpected UniRate response: missing "rates"' unless rates.is_a?(Hash)

        rates.each_with_object({}) do |(code, value), out|
          out[code.to_s.upcase] = BigDecimal(value.to_s)
        end
      end

      def http_get(path, params)
        uri = URI.parse(@base_url)
        uri.path = path
        uri.query = URI.encode_www_form(params.merge("api_key" => @api_key))

        req = Net::HTTP::Get.new(uri)
        req["Accept"] = "application/json"
        req["User-Agent"] = "money-unirate-api/#{MoneyUniRateApi::VERSION}"

        parse(perform(uri, req))
      end

      def perform(uri, req)
        Net::HTTP.start(uri.hostname, uri.port,
                        use_ssl: uri.scheme == "https",
                        open_timeout: @timeout,
                        read_timeout: @timeout) { |http| http.request(req) }
      rescue StandardError => e
        raise UniRateError, "Network error talking to UniRate: #{e.message}"
      end

      def parse(response)
        status = response.code.to_i
        case status
        when 200..299
          JSON.parse(response.body.to_s)
        when 401 then raise UniRateError, "Missing or invalid UniRate API key (HTTP 401)"
        when 403 then raise UniRateError, "This UniRate endpoint requires a Pro subscription (HTTP 403)"
        when 404 then raise UniRateError, "Currency not found or no data available (HTTP 404)"
        when 429 then raise UniRateError, "UniRate rate limit exceeded (HTTP 429)"
        else
          raise UniRateError, "UniRate API error (HTTP #{status}): #{response.body}"
        end
      rescue JSON::ParserError => e
        raise UniRateError, "Failed to parse UniRate response: #{e.message}"
      end
    end
  end
end
