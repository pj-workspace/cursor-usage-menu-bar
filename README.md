# cursor-usage-menu-bar

<p align="center">
  Native macOS menu bar app for <a href="https://cursor.com">Cursor</a> usage, spending, and billing — SwiftUI dashboard with dual-pool analytics, charts, and EN/ZH i18n.
</p>

<p align="center">
  <strong>中文文档</strong> · <a href="README.zh.md">README.zh.md</a>
</p>

<p align="center">
  <a href="https://github.com/pj-workspace/cursor-usage-menu-bar/actions/workflows/build.yml"><img src="https://github.com/pj-workspace/cursor-usage-menu-bar/actions/workflows/build.yml/badge.svg?branch=main" alt="Build" /></a>
  &nbsp;
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT" /></a>
  &nbsp;
  <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey" alt="macOS 14+" /></a>
  &nbsp;
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9" /></a>
</p>

<p align="center">
  <sub>
    <code>cursor</code> · <code>macos</code> · <code>menu-bar</code> · <code>swift</code> · <code>swiftui</code> · <code>usage-tracker</code> · <code>billing</code> · <code>developer-tools</code> · <code>menubar-extra</code> · <code>cursor-ide</code>
  </sub>
</p>

---

## Preview

<p align="center">
  <img src="docs/screenshot/en/usage-tab-overview.png" alt="Usage tab — dual pools and cycle summary" width="440" />
</p>
<p align="center"><sub><b>Usage</b> — today stats, API / Auto + Composer pools, and billing cycle overview</sub></p>

---

### Quota decline & daily charts

<p align="center">
  <img src="docs/screenshot/zh/quota-decline-and-daily-charts.png" alt="Quota decline curve and daily usage percent chart" width="440" />
</p>
<p align="center"><sub>Total / API / Auto quota curves · daily usage as % of billing</sub></p>

---

### Daily spend & model breakdown

<p align="center">
  <img src="docs/screenshot/zh/daily-spend-and-model-chart.png" alt="Daily spend bar chart and model spend pie chart" width="440" />
</p>
<p align="center"><sub>Daily spend with USD bar labels · spend distribution by model</sub></p>

---

### Usage events & pricing rules

<p align="center">
  <img src="docs/screenshot/en/model-distribution-and-events.png" alt="Model filter and usage event pricing detail" width="440" />
</p>
<p align="center"><sub>Paginated events · model filter · official pricing rules & cost estimates</sub></p>

<p align="center">
  <img src="docs/screenshot/zh/usage-events-pricing-detail.png" alt="Expanded usage event with token breakdown" width="440" />
</p>
<p align="center"><sub>Expanded event — token breakdown and rule-based price calculation</sub></p>

---

### Billing & token usage

<p align="center">
  <img src="docs/screenshot/en/billing-tab-overview.png" alt="Billing tab with dual pools and allowance breakdown" width="440" />
</p>
<p align="center"><sub><b>Billing</b> — cycle usage, dual-pool status, allowance notes</sub></p>

<p align="center">
  <img src="docs/screenshot/zh/model-token-usage-and-account.png" alt="Per-model token usage and account info" width="440" />
</p>
<p align="center"><sub>Per-model token totals · account & plan details</sub></p>

---

### Settings

<p align="center">
  <img src="docs/screenshot/en/settings.png" alt="Settings — session token and language picker" width="440" />
</p>
<p align="center"><sub>Session token · auto-refresh pacing · <b>Language: System / English / 中文</b></sub></p>

> All screenshots: [`docs/screenshot/en/`](docs/screenshot/en/) · [`docs/screenshot/zh/`](docs/screenshot/zh/)

---

## Features

- **Menu bar at a glance** — billing cycle usage % with a live gauge icon
- **Three-tab dashboard** aligned with Cursor's web dashboard:
  - **Usage** — today stats, dual pools, quota decline curve, daily charts, paginated events
  - **Spending** — cycle spend, breakdown bars, spend trends
  - **Billing** — cycle summary, dual-pool status, allowance notes, per-model token usage
- **Dual usage pools** — API included allowance vs Auto + Composer bonus; clarifies misleading *usage limit* messages
- **Charts** — daily spend (USD), daily usage %, quota decline (Total / API / Auto), model pie chart
- **Usage event details** — tokens, pricing rules, cost estimates, full-cycle local cache
- **Background sync** — randomized 10–20s request pacing
- **Change notifications** — in-app banner + macOS alerts on usage shifts
- **Bilingual UI** — English & 中文 (Settings → Language)
- **Keychain** — `WorkosCursorSessionToken` stored securely

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+ / Xcode 15+ (build from source)

---

## Quick start

### 1 · Get your session token

1. Sign in at [cursor.com/dashboard/usage](https://cursor.com/dashboard/usage)
2. DevTools → **Application** → **Cookies** → `cursor.com`
3. Copy **`WorkosCursorSessionToken`**

> Uses Cursor's **undocumented dashboard APIs** — may change without notice. **Never commit or share your token.**

### 2 · Build & run

```bash
git clone https://github.com/pj-workspace/cursor-usage-menu-bar.git
cd cursor-usage-menu-bar
chmod +x scripts/build-app.sh
./scripts/build-app.sh release
open dist/CursorUsageMenuBar.app
```

Paste the token in **Settings → Session Token → Save**.

### Development

```bash
swift run
# or: open Package.swift
```

---

## How usage is calculated

Cursor exposes **two billing pools**:

| Pool | Source | Shown as |
|------|--------|----------|
| **API** | Named / third-party models | % of API included allowance ($70 on Pro+) |
| **Auto + Composer** | Auto-routed & Composer models | Bonus spend on top of included API |

**Billing total** (`totalPercentUsed`) is the menu bar headline. *"You've hit your usage limit"* usually means **API included allowance is exhausted**, not that overall billing is at 100%.

Daily charts prorate billing % by each day's share of cycle spend.

---

## API endpoints

| Area | Endpoint | Purpose |
|------|----------|---------|
| Usage | `GET /api/usage-summary` | Cycle limits, dual-pool % |
| Usage | `POST /api/dashboard/get-filtered-usage-events` | Paginated events |
| Usage | `POST /api/dashboard/get-aggregated-usage-events` | Per-model token totals |
| Spending | `POST /api/dashboard/get-current-period-usage` | Cycle spend & pools |
| Billing | `POST /api/dashboard/get-user-profile` | Profile & handle |
| Billing | `GET /api/auth/me` | Email & name |

---

## Project structure

```
cursor-usage-menu-bar/
├── Package.swift
├── Resources/Info.plist
├── scripts/build-app.sh
├── docs/screenshot/{en,zh}/
└── Sources/CursorUsageMenuBar/
    ├── Localization/
    ├── Models/
    ├── Services/
    ├── ViewModels/
    └── Views/
```

---

## Releases

Download binaries from **[GitHub Releases](https://github.com/pj-workspace/cursor-usage-menu-bar/releases)**.

| Version | Notes |
|---------|-------|
| [v0.1.0](https://github.com/pj-workspace/cursor-usage-menu-bar/releases/tag/v0.1.0) | Initial release — dashboard, charts, i18n |

---

## Disclaimer

**Not affiliated with Cursor.** Independent community tool. Session tokens are credentials — treat them like passwords.

---

## License

[MIT](LICENSE) © 2026 Jay Pan
