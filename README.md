# bucu_inventory

> High-Performance Grid Inventory System with Anti-Dupe Mutex Locks, 3D Trunk Sync, WebAudio Haptics, and Physical Cards.

---

## 🌟 Overview

`bucu_inventory` is a next-generation FiveM inventory system built from the ground up to eliminate duplication exploits, optimize network bandwidth, and provide a state-of-the-art Glassmorphism user interface.

## 📦 Features
- **Anti-Dupe Mutex Lock Engine**: Server-authoritative transaction locking preventing race-condition duplicates.
- **40-Slot 30kg Pockets**: Customizable grid slots with dynamic weight bar indicators.
- **WebAudio API Sound Synthesizer**: Procedural, zero-external-asset audio haptics (plastic rustle, metallic clicks, liquid bottles).
- **Physical ID & Driver Badges**: Interactive cards that can be shown to nearby players on their screens.
- **Physical 3D Trunk & Glovebox**: Real vehicle trunk door opening and world prop drops.
- **Smart Radial Context Menu**: Right-click to Use, Split 50%, Give to Nearest Player, or Inspect.
- **Cross-Framework Bridges**: Seamless shims for `qb-inventory` and `esx:addInventoryItem`.

## 📥 Installation
```cfg
ensure oxmysql
ensure bucu_core
ensure bucu_shared
ensure bucu_notify
ensure bucu_inventory
```

## 📜 License
Part of the BUCU Framework. Licensed under the MIT License.
