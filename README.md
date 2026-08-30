# CryptoBar

A lightweight macOS menu bar app that shows live cryptocurrency prices from [CoinGecko](https://www.coingecko.com/). Click the icon to open a panel with your favorites, 24h change, and settings.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- Lives in the menu bar (no Dock icon)
- Tracks Bitcoin, Ethereum, and Solana by default — add or remove any coin
- Auto-refreshes every 60 seconds (configurable: 30s / 60s / 2min)
- Shows 24h price change with green/red coloring
- **Launch at Login** toggle in Settings
- Free CoinGecko API — no key required; optional Demo key for higher rate limits

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build and run

```bash
git clone https://github.com/javier-angel/cryptobar.git
cd cryptobar
xcodegen generate
open CryptoBar.xcodeproj
```

In Xcode, select **My Mac** as the run destination and press **⌘R**. The bitcoin icon appears in your menu bar.

### First launch

1. Click the menu bar icon to open the price panel.
2. Open **Settings** (gear icon) to change coins, currency, refresh interval, or enable **Launch at Login**.
3. macOS may ask you to allow network access — allow it so prices can update.

## Optional: CoinGecko Demo API key

The app works without an API key. If you hit rate limits, sign up for a free Demo key at [coingecko.com/en/api/pricing](https://www.coingecko.com/en/api/pricing) and paste it in Settings.

## Launch at Login

Toggle **Open CryptoBar when you log in** in Settings. This uses Apple's `SMAppService` API (macOS 13+). The first time you enable it, macOS may prompt you to allow the app in **System Settings → General → Login Items**.

> **Note:** Launch at Login works best when the app is built and run from a stable location (e.g. `/Applications/CryptoBar.app`). During development, Xcode runs a temporary build path — move the app to Applications for persistent login items.

## Project structure

```
CryptoBar/
├── CryptoBarApp.swift       App entry point
├── AppDelegate.swift        Menu bar + popover shell
├── Models/                  Coin and PriceQuote types
├── Services/                CoinGecko API, catalog cache, launch-at-login
├── ViewModels/              PriceViewModel (polling + persistence)
└── Views/                   Popover, settings, coin rows
project.yml                  XcodeGen project spec
```

## Data source

Prices come from the CoinGecko `/simple/price` endpoint. One batched request fetches all selected coins. See [CoinGecko API docs](https://docs.coingecko.com/reference/simple-price).

## License

MIT
