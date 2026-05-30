# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-30

### Added

- `Money::Bank::UniRate` — a `Money::Bank::VariableExchange` subclass backed by
  the UniRate API (https://unirateapi.com).
- Single-base snapshot fetch from `GET /api/rates`; all cross-rates derived on
  demand so a TTL refresh never serves a stale pair.
- Lazy fetch on first conversion, optional `ttl_in_seconds` refresh, and
  `flush_rates` to force a refresh.
- Error mapping (`UniRateError`) for auth (401), Pro-gated (403), not-found
  (404), rate-limit (429), network, and malformed-response failures.
- Zero runtime dependencies beyond the `money` gem (pure stdlib HTTP).

[0.1.0]: https://github.com/UniRate-API/money-unirate-api/releases/tag/v0.1.0
