# Manual QA Verification Checklist

Use this guide to verify the features of the Billing & POS application on a physical Android device or emulator.

---

## 1. First Run & Onboarding Setup
- [ ] Install the app on a fresh device.
- [ ] On launch, verify that the **Onboarding Screen** renders.
- [ ] Fill in the onboarding details (Business Name, Phone, Address, Currency, UPI ID).
- [ ] Click **Get Started** and verify that a database row is created.
- [ ] Verify you are redirected to the **Navigation Shell** home screen.

---

## 2. Product Catalog CRUD
- [ ] Open the **Products** tab.
- [ ] Create a Category (e.g. "Beverages"). Verify it renders in the Category tab.
- [ ] Create a Product. Set name, category, price, barcode (or auto-generate), and enable stock tracking.
- [ ] Verify the product is visible in the catalog list.
- [ ] Edit the product's details and check if the updates reflect.
- [ ] Delete a product and verify it is removed from the catalog.

---

## 3. Stock Level Management
- [ ] Open the **Inventory** screen or the stock update modal from a product.
- [ ] Adjust the stock level (e.g., add 50 units, indicating "supplier shipment").
- [ ] Verify that the product's available stock shows the new quantity.
- [ ] Check the **Stock Movement Logs** screen. Ensure a row is recorded of type `IN` with the matching reason.

---

## 4. POS Billing & Checkout Desk
- [ ] Open the **POS Billing** tab.
- [ ] Verify you can search for products by typing their name.
- [ ] Tap the **Barcode Scanner** button, grant camera permissions, scan a product's barcode, and verify it is instantly added to the cart.
- [ ] Verify the item quantities can be incremented, decremented, or removed.
- [ ] Adjust tax rates (e.g., 18%) and flat discounts (e.g., ₹50). Confirm the grand total updates accurately.
- [ ] Click **COMPLETE TRANSACTION**. Select payment method (Cash / UPI).
- [ ] Click **COMPLETE**. Verify the checkout bottom sheet closes, cart is cleared, and an **Invoice Detail Sheet** pops up with the receipt summary.
- [ ] Navigate back to the **Products** screen and verify the stock level has been decremented for the purchased item.
- [ ] Verify a stock movement log of type `OUT` was recorded.

---

## 5. Dashboard & Analytics Reports
- [ ] Open the **Dashboard** screen.
- [ ] Verify the KPI metrics panel displays total sales, total transactions, and low-stock item counts.
- [ ] Verify that the sales graph updates with the transaction data.
- [ ] Go to the **Reports** tab and toggle the time period (Today / Weekly / Monthly). Verify charts update dynamically.
- [ ] Click the PDF icon to export a summary report. Verify the system share dialog launches.

---

## 6. Cloud Backup & Decryption PIN Security
- [ ] Go to the **Settings** screen.
- [ ] Tap **Google Sign-In** and authorize the app. Verify it displays your email profile once authenticated.
- [ ] Tap **Backup to Google Drive**.
- [ ] When prompted, input a Passphrase/PIN.
- [ ] Verify the backup completes successfully.
- [ ] Reinstall the app (or clear local app data).
- [ ] Authenticate with the same Google Account, and click **Restore from Google Drive**.
- [ ] Enter a **wrong** PIN. Verify that decryption fails, and local database tables remain unchanged.
- [ ] Enter the **correct** PIN. Verify the restore succeeds, and your products, categories, stock logs, and checkout history are restored.
