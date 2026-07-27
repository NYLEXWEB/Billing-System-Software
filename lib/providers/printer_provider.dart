import 'dart:io';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/printer_settings.dart';
import '../models/business.dart';
import '../models/invoice.dart';
import '../services/analytics_service.dart';

class PrinterProvider extends ChangeNotifier {
  final DbHelper _dbHelper = DbHelper();

  List<PrinterSettings> _printers = [];
  PrinterSettings? _activePrinter;
  bool _isLoading = false;

  // Bluetooth scan lists
  List<BluetoothInfo> _discoveredDevices = [];
  bool _isScanning = false;
  bool _isConnected = false;

  List<PrinterSettings> get printers => _printers;
  PrinterSettings? get activePrinter => _activePrinter;
  bool get isLoading => _isLoading;
  List<BluetoothInfo> get discoveredDevices => _discoveredDevices;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;

  PrinterProvider() {
    loadPrinters();
  }

  Future<void> loadPrinters() async {
    _isLoading = true;
    notifyListeners();
    try {
      _printers = await _dbHelper.getPrinters();
      if (_printers.isNotEmpty) {
        // If active printer isn't set or no longer exists in list, set to last/newest added
        if (_activePrinter == null || !_printers.any((p) => p.id == _activePrinter!.id)) {
          _activePrinter = _printers.last;
        }
      } else {
        _activePrinter = null;
      }
    } catch (e) {
      debugPrint("Error loading printers: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setActivePrinter(PrinterSettings printer) {
    _activePrinter = printer;
    notifyListeners();
  }

  Future<bool> addPrinter(PrinterSettings printer) async {
    try {
      final id = await _dbHelper.insertPrinter(printer);
      if (id > 0) {
        final newPrinter = printer.copyWith(id: id);
        _activePrinter = newPrinter;
        await loadPrinters();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error adding printer: $e");
      return false;
    }
  }

  Future<bool> deletePrinter(int id) async {
    try {
      final count = await _dbHelper.deletePrinter(id);
      if (count > 0) {
        if (_activePrinter?.id == id) {
          _activePrinter = null;
        }
        await loadPrinters();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting printer: $e");
      return false;
    }
  }

  // ==========================================
  // BLUETOOTH PERMISSIONS, SCANNING & CONNECTING
  // ==========================================

  Future<bool> checkAndRequestBluetoothPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      // Check device bluetooth toggle state
      final bool btEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!btEnabled) {
        debugPrint("Bluetooth is turned off on device");
        return false;
      }

      // Request runtime permissions on Android 12+ (API 31+)
      if (Platform.isAndroid) {
        final statusConnect = await Permission.bluetoothConnect.status;
        if (!statusConnect.isGranted) {
          await Permission.bluetoothConnect.request();
        }
        final statusScan = await Permission.bluetoothScan.status;
        if (!statusScan.isGranted) {
          await Permission.bluetoothScan.request();
        }
      }

      final bool hasPermission = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      return hasPermission;
    } catch (e) {
      debugPrint("Error checking bluetooth permissions: $e");
      return false;
    }
  }

  Future<void> scanBluetoothPrinters() async {
    _isScanning = true;
    _discoveredDevices = [];
    notifyListeners();
    try {
      final bool hasPermission = await checkAndRequestBluetoothPermissions();
      if (!hasPermission) {
        debugPrint("Bluetooth permission not granted or Bluetooth turned off");
        _isScanning = false;
        notifyListeners();
        return;
      }

      final List<BluetoothInfo> pairedList = await PrintBluetoothThermal.pairedBluetooths;
      _discoveredDevices = pairedList;
    } catch (e) {
      debugPrint("Error scanning bluetooth: $e");
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> connectBluetooth(String address) async {
    _isLoading = true;
    notifyListeners();
    try {
      final cleanAddress = address.trim();
      if (cleanAddress.isEmpty) return false;

      // Disconnect stale socket connection if any
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 150));

      final bool connectionStatus = await PrintBluetoothThermal.connect(macPrinterAddress: cleanAddress);
      _isConnected = connectionStatus;
      return connectionStatus;
    } catch (e) {
      debugPrint("Error connecting to Bluetooth printer: $e");
      _isConnected = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> disconnectBluetooth() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _isConnected = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error disconnecting bluetooth: $e");
    }
  }

  // Helper for pure ESC/POS text column formatting (compatible with all 58mm & 80mm printers)
  String _formatTwoColumns(String left, String right, int totalWidth) {
    int spaceCount = totalWidth - left.length - right.length;
    if (spaceCount < 1) {
      final maxLeft = totalWidth - right.length - 1;
      if (maxLeft > 0) {
        left = left.substring(0, maxLeft);
      }
      spaceCount = 1;
    }
    return left + (' ' * spaceCount) + right;
  }

  // Helper for 3-column ESC/POS formatting: Item (Left), Qty (Center), Total (Right)
  String _formatThreeColumns(String left, String center, String right, int totalWidth) {
    final int leftWidth = totalWidth == 48 ? 26 : 16;
    final int centerWidth = totalWidth == 48 ? 8 : 6;
    final int rightWidth = totalWidth == 48 ? 14 : 10;

    String l = left.length > leftWidth ? left.substring(0, leftWidth) : left.padRight(leftWidth);

    String c;
    if (center.length >= centerWidth) {
      c = center.substring(0, centerWidth);
    } else {
      final leftPad = (centerWidth - center.length) ~/ 2;
      final rightPad = centerWidth - center.length - leftPad;
      c = (' ' * leftPad) + center + (' ' * rightPad);
    }

    String r = right.length > rightWidth ? right.substring(0, rightWidth) : right.padLeft(rightWidth);

    return "$l$c$r";
  }

  // Sanitizes text strings to 100% compatible ASCII for thermal printers
  String _cleanText(String input) {
    return input
        .replaceAll('₹', 'Rs. ')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('•', '*')
        .replaceAll('…', '...');
  }

  // Converts numbers to words (Indian numbering system: Rupees, Lakhs, Crores)
  String _numberToWords(double amount) {
    if (amount <= 0) return "Zero Rupees Only";

    final int rupees = amount.floor();
    final int paise = ((amount - rupees) * 100).round();

    String rupeesInWords = _convertIntegerToWords(rupees);
    if (rupeesInWords.isEmpty) rupeesInWords = "Zero";

    String result = "$rupeesInWords ${rupees == 1 ? 'Rupee' : 'Rupees'}";

    if (paise > 0) {
      String paiseInWords = _convertIntegerToWords(paise);
      result += " and $paiseInWords Paise";
    }

    return "$result Only";
  }

  String _convertIntegerToWords(int number) {
    if (number == 0) return "";

    const units = [
      "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
      "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
      "Seventeen", "Eighteen", "Nineteen"
    ];

    const tens = [
      "", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"
    ];

    if (number < 20) return units[number];
    if (number < 100) {
      final unit = number % 10;
      return "${tens[number ~/ 10]}${unit > 0 ? ' ${units[unit]}' : ''}";
    }
    if (number < 1000) {
      final rem = number % 100;
      return "${units[number ~/ 100]} Hundred${rem > 0 ? ' ${_convertIntegerToWords(rem)}' : ''}";
    }
    if (number < 100000) {
      final rem = number % 1000;
      return "${_convertIntegerToWords(number ~/ 1000)} Thousand${rem > 0 ? ' ${_convertIntegerToWords(rem)}' : ''}";
    }
    if (number < 10000000) {
      final rem = number % 100000;
      return "${_convertIntegerToWords(number ~/ 100000)} Lakh${rem > 0 ? ' ${_convertIntegerToWords(rem)}' : ''}";
    }

    final rem = number % 10000000;
    return "${_convertIntegerToWords(number ~/ 10000000)} Crore${rem > 0 ? ' ${_convertIntegerToWords(rem)}' : ''}";
  }

  // ==========================================
  // RECEIPT BUILDER & PRINT TRANSMISSION
  // ==========================================

  Future<List<int>> _buildReceiptBytes({
    required Invoice invoice,
    required Business business,
    required int paperWidth,
  }) async {
    final profile = await CapabilityProfile.load();
    final PaperSize size = paperWidth == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(size, profile);
    final int width = paperWidth == 80 ? 48 : 32;
    List<int> bytes = [];

    bytes += generator.reset();

    // Clean currency symbol (Replace unicode ₹ with ASCII 'Rs.')
    final String currencySym = (business.currency.isEmpty || business.currency == '₹')
        ? 'Rs.'
        : _cleanText(business.currency);

    // 1. Header (Shop Name & Details)
    final String shopName = business.name.isNotEmpty ? _cleanText(business.name) : "EASYTOBILL STORE";
    bytes += generator.text(
      shopName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    // Phone & Address Line (Format: "Phone - Address")
    final String cleanPhone = business.phone.isNotEmpty ? _cleanText(business.phone) : "";
    final String cleanAddr = business.address.isNotEmpty ? _cleanText(business.address) : "";

    if (cleanPhone.isNotEmpty && cleanAddr.isNotEmpty) {
      bytes += generator.text("$cleanPhone | $cleanAddr", styles: const PosStyles(align: PosAlign.center));
    } else if (cleanPhone.isNotEmpty) {
      bytes += generator.text("Tel: $cleanPhone", styles: const PosStyles(align: PosAlign.center));
    } else if (cleanAddr.isNotEmpty) {
      bytes += generator.text(cleanAddr, styles: const PosStyles(align: PosAlign.center));
    }
    if (business.gstOrTin.isNotEmpty) {
      bytes += generator.text("GSTIN: ${_cleanText(business.gstOrTin)}", styles: const PosStyles(align: PosAlign.center, bold: true));
    }
    if (business.receiptHeader.isNotEmpty) {
      final headerLines = business.receiptHeader.split('\n');
      for (var line in headerLines) {
        if (line.trim().isNotEmpty) {
          bytes += generator.text(_cleanText(line.trim()), styles: const PosStyles(align: PosAlign.center));
        }
      }
    }

    bytes += generator.text("-" * width);

    // 2. Invoice Metadata
    bytes += generator.text("Invoice: ${_cleanText(invoice.invoiceNumber)}", styles: const PosStyles(bold: true));
    bytes += generator.text("Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(invoice.dateTime)}");
    if (invoice.customerName.isNotEmpty) {
      bytes += generator.text("Customer: ${_cleanText(invoice.customerName)}");
    }
    if (invoice.customerPhone.isNotEmpty) {
      bytes += generator.text("Phone: ${_cleanText(invoice.customerPhone)}");
    }
    bytes += generator.text("Payment: ${invoice.paymentMethod} (${invoice.paymentStatus})");

    bytes += generator.text("-" * width);

    // 3. Table Header & Items List (Pure ASCII 3-Column Layout: ITEM | QTY | TOTAL)
    bytes += generator.text(
      _formatThreeColumns("ITEM", "QTY", "TOTAL", width),
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text("-" * width);

    final int maxNameLen = width == 48 ? 26 : 16;

    for (var item in invoice.items) {
      final cleanName = _cleanText(item.productName);
      final String qtyStr = item.quantity.toString();
      final String totalStr = item.subtotal.toStringAsFixed(2);

      if (cleanName.length > maxNameLen) {
        bytes += generator.text(cleanName);
        bytes += generator.text(_formatThreeColumns("", qtyStr, totalStr, width));
      } else {
        bytes += generator.text(_formatThreeColumns(cleanName, qtyStr, totalStr, width));
      }
    }

    bytes += generator.text("-" * width);

    // 4. Totals Block
    bytes += generator.text(_formatTwoColumns("Subtotal:", "$currencySym${invoice.totalAmount.toStringAsFixed(2)}", width));

    if (invoice.discountAmount > 0) {
      bytes += generator.text(_formatTwoColumns("Discount:", "-$currencySym${invoice.discountAmount.toStringAsFixed(2)}", width));
    }

    if (invoice.taxAmount > 0) {
      bytes += generator.text(_formatTwoColumns("Tax / GST:", "+$currencySym${invoice.taxAmount.toStringAsFixed(2)}", width));
    }

    bytes += generator.text(
      _formatTwoColumns("Grand Total:", "$currencySym${invoice.grandTotal.toStringAsFixed(2)}", width),
      styles: const PosStyles(bold: true),
    );

    final String amountInWords = _numberToWords(invoice.grandTotal);
    bytes += generator.text("$amountInWords");

    bytes += generator.text("-" * width);

    // 5. Footer Messages
    if (business.receiptFooter.isNotEmpty) {
      final footerLines = business.receiptFooter.split('\n');
      for (var line in footerLines) {
        if (line.trim().isNotEmpty) {
          bytes += generator.text(_cleanText(line.trim()), styles: const PosStyles(align: PosAlign.center));
        }
      }
    } else {
      bytes += generator.text("Thank You for Shopping!", styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text("Please Visit Again", styles: const PosStyles(align: PosAlign.center));
    }

    bytes += generator.text("Powered by EasyToBill", styles: const PosStyles(align: PosAlign.center));

    // 7. Paper Feed & Cutter
    bytes += generator.feed(3);

    if (paperWidth == 80) {
      try {
        bytes += generator.cut();
      } catch (_) {}
    }

    return bytes;
  }

  Future<bool> _sendBytesToActivePrinter(List<int> bytes) async {
    if (_activePrinter == null) {
      debugPrint("No active printer configured");
      return false;
    }

    if (_activePrinter!.type == 'bluetooth') {
      try {
        final bool hasPermission = await checkAndRequestBluetoothPermissions();
        if (!hasPermission) {
          debugPrint("Bluetooth permission not granted or Bluetooth turned off");
          return false;
        }

        // Check if currently connected
        bool status = await PrintBluetoothThermal.connectionStatus;
        if (!status) {
          status = await connectBluetooth(_activePrinter!.address);
        }

        if (!status) {
          debugPrint("Failed to establish bluetooth connection to ${_activePrinter!.address}");
          return false;
        }

        // Direct write of full receipt bytes payload
        bool writeSuccess = await PrintBluetoothThermal.writeBytes(bytes);
        if (!writeSuccess) {
          debugPrint("Direct write returned false, reconnecting and retrying...");
          await connectBluetooth(_activePrinter!.address);
          writeSuccess = await PrintBluetoothThermal.writeBytes(bytes);
        }

        return writeSuccess;
      } catch (e) {
        debugPrint("Error in bluetooth print execution: $e");
        return false;
      }
    } else if (_activePrinter!.type == 'network') {
      // Wi-Fi / LAN Network Socket Printing
      try {
        final addressParts = _activePrinter!.address.split(':');
        final String ip = addressParts[0];
        final int port = addressParts.length > 1 ? int.parse(addressParts[1]) : 9100;

        final Socket socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        return true;
      } catch (e) {
        debugPrint("Error writing Wi-Fi network print socket: $e");
        return false;
      }
    }

    return false;
  }

  Future<bool> printInvoice(Invoice invoice, Business business) async {
    if (_activePrinter == null) {
      debugPrint("No active printer selected");
      return false;
    }

    final bytes = await _buildReceiptBytes(
      invoice: invoice,
      business: business,
      paperWidth: _activePrinter!.paperWidth,
    );

    final bool printResult = await _sendBytesToActivePrinter(bytes);

    if (printResult) {
      AnalyticsService.logBillPrinted(invoice.invoiceNumber);
    }

    return printResult;
  }

  Future<bool> testPrintActivePrinter(Business business) async {
    if (_activePrinter == null) return false;

    final profile = await CapabilityProfile.load();
    final PaperSize size = _activePrinter!.paperWidth == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(size, profile);
    final int width = _activePrinter!.paperWidth == 80 ? 48 : 32;
    List<int> bytes = [];

    bytes += generator.reset();
    bytes += generator.text(
      "EASYTOBILL TEST",
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text(business.name.isNotEmpty ? _cleanText(business.name) : "Sample Store", styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text("-" * width);
    bytes += generator.text("Printer: ${_cleanText(_activePrinter!.name)}");
    bytes += generator.text("Type: ${_activePrinter!.type.toUpperCase()}");
    bytes += generator.text("MAC/IP: ${_activePrinter!.address}");
    bytes += generator.text("Paper: ${_activePrinter!.paperWidth} mm");
    bytes += generator.text("Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}");
    bytes += generator.text("-" * width);
    bytes += generator.text("PRINTER TEST SUCCESSFUL!", styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text("EasyToBill POS Ready", styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(3);

    if (_activePrinter!.paperWidth == 80) {
      try {
        bytes += generator.cut();
      } catch (_) {}
    }

    return await _sendBytesToActivePrinter(bytes);
  }
}

