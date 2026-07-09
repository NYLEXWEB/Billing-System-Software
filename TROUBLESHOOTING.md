# System Diagnostics & Troubleshooting Guide

This guide describes common issues, diagnostic procedures, and resolutions when working with hardware or cloud backup layers.

## 1. Bluetooth Thermal Printers

### Connection Failure / Timeout
- **Symptoms**: The printer discovery sheet is empty, or selecting a printer hangs and fails.
- **Resolution Checklist**:
  1. Ensure the printer is powered on and paired with the host device in Android settings.
  2. Verify that Bluetooth is enabled on the mobile device.
  3. Ensure location services are enabled (older Android versions require location to discover BLE and RFCOMM services).
  4. Disconnect any other tablet or phone that might be currently connected to the printer (most low-cost thermal printers only support one active connection at a time).

---

## 2. Wi-Fi / TCP Printers

### Socket Connection Error (Port 9100)
- **Symptoms**: Printing throws a network connection timeout exception.
- **Resolution Checklist**:
  1. Ensure the POS printer and mobile device are connected to the exact same local Wi-Fi router.
  2. Double-check the printer's IP address (print a self-test page by holding the Feed button while turning on the printer to check its assigned IP address).
  3. Ping the printer's IP address from your terminal or another diagnostics tool to confirm accessibility.
  4. Ensure port `9100` (raw print channel) is not blocked by a firewall or router client isolation.

---

## 3. Google Drive Backups

### AuthClient Authorization Failures
- **Symptoms**: Backups fail immediately, or Google Sign-In prompts repeatedly.
- **Resolution Checklist**:
  1. Verify the app's signing keys (SHA-1 fingerprint) are registered in the Google Cloud Console credentials desk for OAuth 2.0 Client IDs.
  2. Make sure the Google Drive API is enabled in your Google Cloud Project.
  3. Verify internet connectivity (backups require an active online connection).
  4. Check if the passphrase meets storage parameters. Decryption will fail if a different passphrase is typed during restoration.

---

## 4. Local Database Errors

### Database Version Migrations
- **Symptoms**: App crashes immediately after an update that added a new database column.
- **Resolution Checklist**:
  1. Database updates increment the schema version in `DbHelper`.
  2. Ensure table column adjustments are added inside the `onUpgrade` switch in `lib/data/db_helper.dart`.
  3. If working in a development build, clear the app data or reinstall the app to reinitialize a fresh SQLite file.
