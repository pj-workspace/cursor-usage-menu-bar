# CursorUsageMenuBar

[![Build](https://github.com/pj-workspace/CursorUsageMenuBar/actions/workflows/build.yml/badge.svg)](https://github.com/pj-workspace/CursorUsageMenuBar/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)

A native **macOS menu bar app** that surfaces [Cursor](https://cursor.com) usage, spending, and billing data in one place — without opening the browser dashboard every time.

**Keywords:** `cursor` · `macos` · `menu-bar` · `swift` · `swiftui` · `usage-tracker` · `billing` · `api-monitoring` · `developer-tools` · `menubar-extra`

---

## Preview

<p align="center">
  <img src="docs/screenshot/en/usage-tab-overview.png" alt="CursorUsageMenuBar — Usage tab overview" width="420" />
</p>

| Usage & dual pools | Quota decline & daily charts |
|:---:|:---:|
| <img src="docs/screenshot/en/usage-tab-overview.png" width="380" /> | <img src="docs/screenshot/zh/quota-decline-and-daily-charts.png" width="380" /> |

| Daily spend & models | Billing & token breakdown |
|:---:|:---:|
| <img src="docs/screenshot/zh/daily-spend-and-model-chart.png" width="380" /> | <img src="docs/screenshot/en/billing-tab-overview.png" width="380" /> |

| Usage events & pricing | Settings |
|:---:|:---:|
| <img src="docs/screenshot/en/model-distribution-and-events.png" width="380" /> | <img src="docs/screenshot/en/settings.png" width="380" /> |

> More screenshots: [`docs/screenshot/en/`](docs/screenshot/en/) (English UI) · [`docs/screenshot/zh/`](docs/screenshot/zh/) (中文界面)

---

## Features

- **Menu bar at a glance** — billing cycle usage % with a live gauge icon
- **Three-tab dashboard** aligned with Cursor's web dashboard:
  - **Usage** — today stats, dual pools (API vs Auto + Composer), quota decline curve, daily charts, paginated event log
  - **Spending** — cycle spend, breakdown bars, spend trends
  - **Billing** — cycle summary, dual-pool status, allowance notes, per-model token usage, account info
- **Dual usage pools** — API included allowance vs Auto + Composer bonus spend, with clear explanations when API limit messages appear
- **Charts** — daily spend (USD labels), daily usage % of billing, quota decline (Total / API / Auto), model spend pie chart
- **Usage event details** — token counts, official pricing rules, rule-based cost estimates, full-cycle local cache for fast filter & pagination
- **Background sync** — randomized 10–20s request pacing to reduce fixed traffic patterns
- **Change notifications** — in-app banner + macOS notification when usage shifts
- **Bilingual UI** — English & 中文 (Settings → Language: System / English / 中文)
- **Secure token storage** — `WorkosCursorSessionToken` in macOS Keychain

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+ / Xcode 15+ (to build from source)

---

## Quick start

### 1. Get your session token

1. Sign in at [cursor.com/dashboard/usage](https://cursor.com/dashboard/usage)
2. Open DevTools → **Application** → **Cookies** → `cursor.com`
3. Copy the value of **`WorkosCursorSessionToken`**

> This uses Cursor's **undocumented dashboard APIs**. They may change without notice. **Never commit your token** or share it publicly.

### 2. Build & run

```bash
git clone https://github.com/pj-workspace/CursorUsageMenuBar.git
cd CursorUsageMenuBar
chmod +x scripts/build-app.sh
./scripts/build-app.sh release
open dist/CursorUsageMenuBar.app
```

Paste the token in **Settings → Session Token → Save**. The menu bar icon appears immediately; the dashboard opens from the menu bar extra.

### Development (Swift Package)

```bash
swift run
# or
open Package.swift   # Run in Xcode (⌘R)
```

---

## How usage is calculated

Cursor exposes **two billing pools**:

| Pool | Typical source | Shown as |
|------|----------------|----------|
| **API** | Named / third-party models | % of API included allowance ($70 on Pro+) |
| **Auto + Composer** | Auto-routed & Composer models | Bonus spend on top of included API |

**Billing total** (`totalPercentUsed`) is the headline % in the menu bar. When the dashboard says *"You've hit your usage limit"*, it usually means the **API included allowance is exhausted**, not that overall billing is at 100% — the app surfaces both messages side by side.

Daily charts prorate billing % by each day's share of cycle spend (aligned with common community tooling such as CursorHub).

---

## API endpoints used

| Area | Endpoint | Purpose |
|------|----------|---------|
| Usage | `GET /api/usage-summary` | Cycle limits, dual-pool %, billing messages |
| Usage | `POST /api/dashboard/get-filtered-usage-events` | Paginated usage events |
| Usage | `POST /api/dashboard/get-aggregated-usage-events` | Per-model token totals |
| Spending | `POST /api/dashboard/get-current-period-usage` | Cycle spend & pool breakdown |
| Billing | `POST /api/dashboard/get-user-profile` | Profile & handle |
| Billing | `GET /api/auth/me` | Email & display name |

---

## Project structure

```
CursorUsageMenuBar/
├── Package.swift
├── Resources/Info.plist          # LSUIElement — no Dock icon
├── scripts/build-app.sh            # Bundle → dist/CursorUsageMenuBar.app
├── docs/screenshot/              # README screenshots (en/ + zh/)
└── Sources/CursorUsageMenuBar/
    ├── CursorUsageMenuBarApp.swift
    ├── Localization/               # en/zh strings
    ├── Models/
    ├── Services/                   # API client, analytics, cache, pricing
    ├── ViewModels/
    └── Views/
```

---

## Releases

Download pre-built binaries from **[GitHub Releases](https://github.com/pj-workspace/CursorUsageMenuBar/releases)**.

| Version | Notes |
|---------|-------|
| [v0.1.0](https://github.com/pj-workspace/CursorUsageMenuBar/releases/tag/v0.1.0) | Initial open-source release — Usage / Spending / Billing dashboard, charts, i18n |

---

## Disclaimer

This project is **not affiliated with or endorsed by Cursor**. It is an independent community tool. Use at your own risk. Session tokens grant access to your account — treat them like passwords.

---

## License

[MIT](LICENSE) © 2026 Jay Pan

---

## 中文说明

**CursorUsageMenuBar** 是一款原生 macOS **菜单栏**应用，在本地展示 Cursor 的用量、花费与账单数据，无需频繁打开浏览器 Dashboard。

### 主要功能

- 菜单栏显示本周期 Billing 用量百分比
- **用量 / 花费 / 账单** 三页仪表盘，对齐官网三个页面
- **双用量池**：API 包含额度与 Auto + Composer，并解释「usage limit」的真实含义
- 额度下降曲线、每日花费/用量图表、模型分布、用量明细分页
- 全量事件本地缓存、计费规则与 Token 估价
- **中英双语**（设置 → 语言）
- Token 存 Keychain，后台随机间隔刷新

### 构建

```bash
git clone https://github.com/pj-workspace/CursorUsageMenuBar.git
cd CursorUsageMenuBar
./scripts/build-app.sh release
open dist/CursorUsageMenuBar.app
```

在设置中粘贴 `WorkosCursorSessionToken` 即可使用。截图见 [`docs/screenshot/zh/`](docs/screenshot/zh/)。

### 截图索引（中文界面）

| 文件 | 说明 |
|------|------|
| `usage-tab-overview.png` | 用量页总览、双池仪表盘 |
| `quota-decline-and-daily-charts.png` | 额度下降曲线与每日用量 |
| `daily-spend-and-model-chart.png` | 每日花费与模型分布 |
| `model-distribution-and-events.png` | 模型饼图与用量明细 |
| `usage-events-pricing-detail.png` | 明细展开与计费规则 |
| `billing-tab-overview.png` | 账单页与额度说明 |
| `model-token-usage-and-account.png` | 模型 Token 用量与账户 |
| `settings.png` | 设置与语言切换 |

---

<p align="center">
  <sub>Built with SwiftUI · Charts · MenuBarExtra</sub>
</p>
