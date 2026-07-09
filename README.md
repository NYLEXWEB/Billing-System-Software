# Offline-First Billing & POS Application

A premium, production-ready, offline-first Flutter application designed for retail point-of-sale operations. Fully equipped with SQLite local storage, Google Drive encrypted backup schedules, camera-based barcode scanning, and ESC/POS thermal printing.

---

## Features

- **Offline-First Storage**: Core operations (transaction desk, inventory ledger, catalog) run directly on a local SQLite database for maximum reliability.
- **Client-Side Cryptography**: Backup files are encrypted client-side using **AES-256-CBC** with key derivation via **PBKDF2** using a user passphrase before being saved to Google Drive.
- **Hardware Integrations**:
  - **ESC/POS Printing**: Wireless Bluetooth (RFCOMM) and Wi-Fi/LAN TCP socket direct printing. Supports 58mm/80mm widths and generates dynamic UPI payment QR codes.
  - **Camera Barcode Scanner**: Quick item lookups with camera scan frames, vibration feedback, and audio cues.
- **Inventory Ledger**: Real-time stock counts, automatic sales deductions, low-stock thresholds, and stock movement logs.
- **Dashboard & Reports**: Dynamic sales trends, analytics graphs (`fl_chart`), and PDF export configurations.
- **Design & Layout**: Modern fluid navigation, light/dark mode theme configurations, and glassmorphic micro-animations.

---

## Technical Documentation Guides

For comprehensive guidelines and developer workflows, refer to the individual documents:

- 🏗️ **[System Architecture](ARCHITECTURE.md)**: Design patterns, directory structure, data flows, and code abstractions.
- 🗄️ **[Database Storage Schema](DATABASE.md)**: SQLite tables, indexing optimizations, and atomic transaction rollback structures.
- 🖨️ **[Thermal Printing Setup](PRINTER_GUIDE.md)**: Connecting Bluetooth and network printers, formatting ESC/POS layouts, and QR rendering.
- 🔑 **[Google Drive Backup & PIN Security](BACKUP_RESTORE.md)**: OAuth scopes, PBKDF2 key derivation, AES encryption, and restore validations.
- 🧪 **[Testing Framework](TESTING.md)**: Running automated tests, mock configurations, and coverage details.
- 🔧 **[Diagnostics & Troubleshooting](TROUBLESHOOTING.md)**: Solving connection errors, backup authentication issues, and migration warnings.
- 📦 **[App Release & AppBundle Signing](RELEASE_GUIDE.md)**: Keystore file generation, key properties setup, and release compilation.
- ✅ **[Manual QA Verification Checklist](MANUAL_QA_CHECKLIST.md)**: Physical device verification steps to validate each core flow.

---

## Getting Started

### Prerequisites

- Flutter SDK cloned at `D:\flutter` or configured in system environment PATH.
- Android SDK configured (for compiling APKs).

### Installation & Run

1. Clone or copy the project files to your workspace.
2. Resolve Dart packages:
   ```bash
   flutter pub get
   ```
3. Run the automated test suites:
   ```bash
   flutter test
   ```
4. Run the app in development mode on a connected device:
   ```bash
   flutter run
   ```
