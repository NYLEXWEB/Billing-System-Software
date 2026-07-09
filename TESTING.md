# Testing Architecture & Execution

This document details the automated unit test suites and guidance for running them on this Billing/POS application.

## Automated Test Suites

We implement two testing suites to verify transactional math calculations and database model conversion symmetry.

### 1. Cart Financial Calculations (`test/cart_test.dart`)
Validates that the shopping cart performs arithmetic computations correctly, including handling edge cases:
- Symmetrical unit totals for items.
- Correct order subtotal computation.
- Discount deductions and compound tax rates.
- Enforcing inventory stock quantity boundary limits for tracked items.
- Correct URL encoding for UPI payment strings (handling special characters like `&` and spaces).

### 2. Model Mapping Tests (`test/widget_test.dart`)
Validates that SQLite serialization (`toMap`) and deserialization (`fromMap`) conversions are fully symmetrical for all database entities:
- `Business`
- `Product`
- `Category`
- `Invoice`
- `InvoiceItem`

---

## Running the Tests

To run the automated test suite locally:

```powershell
# Run all tests
flutter test

# Run tests in verbose mode to see individual tests
flutter test -v
```

---

## Manual QA Verification Checklist

For details on manual validation procedures and physical device testing (including barcode scanners, thermal printers, and cloud backup flows), refer to [MANUAL_QA_CHECKLIST.md](MANUAL_QA_CHECKLIST.md).
