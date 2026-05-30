# frozen_string_literal: true

RSpec.describe Money::Bank::UniRate do
  let(:api_key) { "test-key" }
  let(:base_url) { "https://api.unirateapi.com" }

  # USD-based snapshot used by most examples.
  let(:rates_body) do
    { "rates" => { "EUR" => "0.90", "GBP" => "0.80", "JPY" => "150.0" } }.to_json
  end

  def stub_rates(body: rates_body, status: 200, from: "USD")
    stub_request(:get, "#{base_url}/api/rates")
      .with(query: hash_including("from" => from, "api_key" => api_key))
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  subject(:bank) { described_class.new(api_key: api_key) }

  describe "#initialize" do
    it "raises without an api key" do
      expect { described_class.new(api_key: nil) }.to raise_error(ArgumentError, /api_key is required/)
      expect { described_class.new(api_key: "") }.to raise_error(ArgumentError, /api_key is required/)
    end

    it "reads the api key from ENV when not passed" do
      stub_const("ENV", ENV.to_h.merge("UNIRATE_API_KEY" => "env-key"))
      expect { described_class.new }.not_to raise_error
    end

    it "defaults the base currency to USD and upcases overrides" do
      expect(described_class.new(api_key: api_key).base_currency).to eq("USD")
      expect(described_class.new(api_key: api_key, base_currency: "eur").base_currency).to eq("EUR")
    end
  end

  describe "#update_rates" do
    it "fetches the snapshot once and stores base->currency rates" do
      req = stub_rates
      bank.update_rates

      expect(bank.get_rate("USD", "EUR")).to eq(BigDecimal("0.90"))
      expect(bank.get_rate("USD", "GBP")).to eq(BigDecimal("0.80"))
      expect(req).to have_been_requested.once
    end

    it "sends Accept: application/json (the /api/currencies + parity header)" do
      stub_rates
      bank.update_rates
      expect(
        a_request(:get, "#{base_url}/api/rates")
          .with(query: hash_including("from" => "USD"), headers: { "Accept" => "application/json" })
      ).to have_been_requested
    end

    it "identifies itself with a versioned User-Agent" do
      stub_rates
      bank.update_rates
      expect(
        a_request(:get, "#{base_url}/api/rates")
          .with(query: hash_including("from" => "USD"),
                headers: { "User-Agent" => "money-unirate-api/#{MoneyUniRateApi::VERSION}" })
      ).to have_been_requested
    end
  end

  describe "#get_rate" do
    before { stub_rates }

    it "fetches lazily on first use (no explicit update_rates)" do
      expect(bank.get_rate("USD", "EUR")).to eq(BigDecimal("0.90"))
    end

    it "returns 1 for identical currencies without hitting the network" do
      expect(bank.get_rate("USD", "USD")).to eq(1)
      expect(a_request(:get, "#{base_url}/api/rates")).not_to have_been_requested
    end

    it "derives a cross-rate from the single-base snapshot" do
      # EUR->GBP = (USD->GBP) / (USD->EUR) = 0.80 / 0.90
      expect(bank.get_rate("EUR", "GBP")).to be_within(1e-12).of(BigDecimal("0.80") / BigDecimal("0.90"))
    end

    it "derives the inverse rate back to the base currency" do
      # EUR->USD = 1 / (USD->EUR) = 1 / 0.90
      expect(bank.get_rate("EUR", "USD")).to be_within(1e-12).of(BigDecimal(1) / BigDecimal("0.90"))
    end

    it "raises UniRateError for a currency missing from the snapshot" do
      expect { bank.get_rate("USD", "CHF") }.to raise_error(Money::Bank::UniRateError, /No UniRate rate/)
    end
  end

  describe "Money exchange integration" do
    before { stub_rates }

    it "converts a direct pair" do
      result = bank.exchange_with(Money.new(100, "USD"), "EUR")
      expect(result.fractional).to eq(90) # 100c * 0.90
      expect(result.currency.iso_code).to eq("EUR")
    end

    it "converts a derived cross pair" do
      # 100 EUR cents * (0.80/0.90) = 88.88 -> 89 cents
      result = bank.exchange_with(Money.new(100, "EUR"), "GBP")
      expect(result.fractional).to eq(89)
    end

    it "works as Money.default_bank" do
      original = Money.default_bank
      Money.default_bank = bank
      expect(Money.new(100, "USD").exchange_to("EUR").fractional).to eq(90)
    ensure
      Money.default_bank = original
    end
  end

  describe "caching + refresh" do
    it "fetches once and reuses the snapshot when ttl is nil" do
      req = stub_rates
      bank.get_rate("USD", "EUR")
      bank.get_rate("USD", "GBP")
      bank.get_rate("EUR", "GBP")
      expect(req).to have_been_requested.once
    end

    it "re-fetches after flush_rates" do
      stub_request(:get, "#{base_url}/api/rates")
        .with(query: hash_including("from" => "USD", "api_key" => api_key))
        .to_return(
          { status: 200, body: { "rates" => { "EUR" => "0.90" } }.to_json },
          { status: 200, body: { "rates" => { "EUR" => "0.95" } }.to_json }
        )

      expect(bank.get_rate("USD", "EUR")).to eq(BigDecimal("0.90"))
      bank.flush_rates
      expect(bank.get_rate("USD", "EUR")).to eq(BigDecimal("0.95"))
    end

    it "is expired before first fetch and fresh afterwards (nil ttl)" do
      stub_rates
      expect(bank.expired?).to be(true)
      bank.update_rates
      expect(bank.expired?).to be(false)
    end
  end

  describe "error mapping" do
    it "maps 401 to a UniRateError" do
      stub_rates(status: 401, body: "unauthorized")
      expect { bank.update_rates }.to raise_error(Money::Bank::UniRateError, /401/)
    end

    it "maps 403 (Pro-gated) to a UniRateError" do
      stub_rates(status: 403, body: "forbidden")
      expect { bank.update_rates }.to raise_error(Money::Bank::UniRateError, /Pro subscription/)
    end

    it "maps 429 to a UniRateError" do
      stub_rates(status: 429, body: "slow down")
      expect { bank.update_rates }.to raise_error(Money::Bank::UniRateError, /rate limit/)
    end

    it "raises on a response missing the rates key" do
      stub_rates(body: { "oops" => true }.to_json)
      expect { bank.update_rates }.to raise_error(Money::Bank::UniRateError, /missing "rates"/)
    end

    it "raises on invalid JSON" do
      stub_rates(body: "not json{")
      expect { bank.update_rates }.to raise_error(Money::Bank::UniRateError, /parse/)
    end
  end
end
