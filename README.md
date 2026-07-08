# money-unirate-api

A [`Money::Bank`](https://github.com/RubyMoney/money) implementation backed by
the [UniRate API](https://unirateapi.com) — free, real-time currency exchange
rates for the [`money`](https://rubygems.org/gems/money) gem.

- Drop-in `Money::Bank::UniRate` for `Money.default_bank`
- One HTTP call per snapshot: fetches a single base currency, **derives every
  cross-rate on demand** (so a refresh never serves a stale pair)
- Lazy fetch on first conversion + optional TTL-based refresh
- 170+ currencies (fiat + crypto) via UniRate
- Free tier, no credit card required
- Zero runtime dependencies beyond `money` (pure stdlib `net/http` + `json`)

> **Affiliation:** this gem is maintained by the UniRate team. It talks to the
> UniRate API. If you only need euro-area rates the ECB feed (e.g.
> `eu_central_bank`) may suit you better; for a broad multi-currency source on
> a free tier, UniRate is a good fit.

## Requirements

- Ruby 3.0+
- `money` 6.13+

## Installation

```ruby
# Gemfile
gem "money-unirate-api"
```

```bash
bundle install
# or
gem install money-unirate-api
```

## Quick start

```ruby
require "money"
require "money/bank/uni_rate"

Money.default_bank = Money::Bank::UniRate.new(
  api_key: ENV.fetch("UNIRATE_API_KEY")
)

Money.new(100_00, "USD").exchange_to("EUR")  # => #<Money fractional:9200 currency:EUR>
Money.new(50_00, "EUR").exchange_to("GBP")   # cross-rate derived from the USD snapshot
```

Get a free API key at [unirateapi.com](https://unirateapi.com).

## Configuration

```ruby
Money::Bank::UniRate.new(
  api_key:        ENV.fetch("UNIRATE_API_KEY"), # falls back to ENV["UNIRATE_API_KEY"]
  base_currency:  "USD",   # currency the snapshot is fetched against
  ttl_in_seconds: 3600,    # re-fetch interval; nil (default) = fetch once and cache
  timeout:        30       # per-request timeout in seconds
)
```

| Option | Default | Description |
|---|---|---|
| `api_key` | `ENV["UNIRATE_API_KEY"]` | UniRate API key (required) |
| `base_currency` | `"USD"` | Currency the single snapshot is fetched against |
| `ttl_in_seconds` | `nil` | Seconds before an automatic re-fetch; `nil` fetches once |
| `timeout` | `30` | Per-request open/read timeout |

## How it works

UniRate's `/api/rates` returns every rate for one base currency in a single
response. This bank fetches that snapshot and stores `base → currency` rates.
Any pair you ask for is derived from those:

```
rate(FROM, TO) = rate(base, TO) / rate(base, FROM)
```

Cross-rates are computed **per call**, not cached in the rate store — so when
the snapshot refreshes (via `ttl_in_seconds` or `flush_rates`), there are no
stale derived pairs left behind.

```ruby
bank = Money::Bank::UniRate.new(api_key: "...", ttl_in_seconds: 3600)

bank.update_rates       # warm the cache up front (optional; otherwise lazy)
bank.get_rate("EUR", "GBP")  # derived from the base snapshot
bank.expired?           # => false until the TTL elapses
bank.flush_rates        # force a re-fetch on the next conversion
```

## Error handling

Every failure raises `Money::Bank::UniRateError`:

```ruby
begin
  Money.new(100, "USD").exchange_to("EUR", bank)
rescue Money::Bank::UniRateError => e
  warn "FX lookup failed: #{e.message}"
end
```

Mapped responses: `401` (bad/missing key), `403` (Pro-gated endpoint), `404`
(unknown currency), `429` (rate limit), network errors, and malformed responses.

## Development

```bash
bundle install
bundle exec rspec      # ~20 WebMock-based mock tests
bundle exec rubocop
```

<!-- unirate-ecosystem-footer:start -->
## UniRate ecosystem

UniRate ships official integrations for 40+ ecosystems, all maintained under the
[UniRate-API](https://github.com/UniRate-API) org.

**Core clients (9 languages)**
[Python](https://github.com/UniRate-API/unirate-api-python) ·
[Node.js / TypeScript](https://github.com/UniRate-API/unirate-api-nodejs) ·
[Go](https://github.com/UniRate-API/unirate-api-go) ·
[Rust](https://github.com/UniRate-API/unirate-api-rust) ·
[Java](https://github.com/UniRate-API/unirate-api-java) ·
[Ruby](https://github.com/UniRate-API/unirate-api-ruby) ·
[PHP](https://github.com/UniRate-API/unirate-api-php) ·
[.NET](https://github.com/UniRate-API/unirate-api-dotnet) ·
[Swift](https://github.com/UniRate-API/unirate-api-swift)

**JavaScript / TypeScript**
[React](https://github.com/UniRate-API/react-unirate) ·
[Next.js](https://github.com/UniRate-API/next-unirate) ·
[Remix](https://github.com/UniRate-API/remix-unirate) ·
[SvelteKit](https://github.com/UniRate-API/sveltekit-unirate) ·
[Vue](https://github.com/UniRate-API/vue-unirate) ·
[Angular](https://github.com/UniRate-API/angular-unirate) ·
[Nuxt](https://github.com/UniRate-API/nuxt-unirate) ·
[NestJS](https://github.com/UniRate-API/nestjs-unirate) ·
[tRPC](https://github.com/UniRate-API/trpc-unirate)

**Static-site generators**
[Astro](https://github.com/UniRate-API/astro-unirate) ·
[Eleventy](https://github.com/UniRate-API/eleventy-unirate) ·
[Hugo](https://github.com/UniRate-API/hugo-unirate) ·
[Jekyll](https://github.com/UniRate-API/jekyll-unirate)

**CMS & e-commerce**
[Wagtail](https://github.com/UniRate-API/wagtail-unirate) ·
[WordPress](https://github.com/UniRate-API/unirate-currency-converter) ·
[WooCommerce](https://github.com/UniRate-API/unirate-woocs) ·
[Drupal](https://github.com/UniRate-API/drupal-unirate) ·
[Strapi](https://github.com/UniRate-API/strapi-plugin-unirate) ·
[Medusa](https://github.com/UniRate-API/medusa-plugin-unirate) ·
[Symfony](https://github.com/UniRate-API/unirate-bundle) ·
[Laravel](https://github.com/UniRate-API/laravel-money-unirate) ·
[Directus](https://github.com/UniRate-API/directus-extension-unirate)

**Data, AI & backend**
[LangChain (Python)](https://github.com/UniRate-API/langchain-unirate) ·
[LangChain.js](https://github.com/UniRate-API/langchain-js-unirate) ·
[FastAPI](https://github.com/UniRate-API/fastapi-unirate) ·
[Flask](https://github.com/UniRate-API/flask-unirate) ·
[Django REST Framework](https://github.com/UniRate-API/djangorestframework-unirate) ·
[Apache Airflow](https://github.com/UniRate-API/airflow-provider-unirate) ·
[dbt](https://github.com/UniRate-API/dbt-unirate)

**Platform & tools**
[MCP server](https://github.com/UniRate-API/unirate-mcp) ·
[CLI](https://github.com/UniRate-API/unirate-cli) ·
[Cloudflare Workers](https://github.com/UniRate-API/cloudflare-workers-unirate) ·
[Home Assistant](https://github.com/UniRate-API/unirate-home-assistant) ·
[n8n](https://github.com/UniRate-API/n8n-nodes-unirate) ·
[Google Sheets](https://github.com/UniRate-API/unirate-sheets) ·
[VS Code](https://github.com/UniRate-API/vscode-unirate) ·
[Obsidian](https://github.com/UniRate-API/obsidian-currency)

**Money library bridges**
[money gem (Ruby)](https://github.com/UniRate-API/money-unirate-api) ·
[NodaMoney (.NET)](https://github.com/UniRate-API/UniRateApi.NodaMoney)

Get a free API key at [unirateapi.com](https://unirateapi.com).
<!-- unirate-ecosystem-footer:end -->

## License

MIT — see [LICENSE](LICENSE).