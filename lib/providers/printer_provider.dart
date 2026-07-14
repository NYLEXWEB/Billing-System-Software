import 'dart:io';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/printer_settings.dart';
import '../models/business.dart';
import '../models/invoice.dart';

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
        // Set first printer as default/active
        _activePrinter = _printers.first;
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
  // BLUETOOTH SCANNING & CONNECTING
  // ==========================================

  Future<void> scanBluetoothPrinters() async {
    _isScanning = true;
    _discoveredDevices = [];
    notifyListeners();
    try {
      // Check bluetooth permissions first
      final bool hasPermission = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!hasPermission) {
        debugPrint("Bluetooth permission not granted");
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
      final bool connectionStatus = await PrintBluetoothThermal.connect(macPrinterAddress: address);
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

  // ==========================================
  // RECEIPT BUILDER & PRINT TRIGGER
  // ==========================================

  Future<List<int>> _buildReceiptBytes({
    required Invoice invoice,
    required Business business,
    required int paperWidth,
  }) async {
    final profile = await CapabilityProfile.load();
    final PaperSize size = paperWidth == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(size, profile);
    List<int> bytes = [];

    // Header (Center Aligned)
    bytes += generator.text(
      business.name.toUpperCase(),
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    if (business.address.isNotEmpty) {
      bytes += generator.text(business.address, styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.text("Tel: ${business.phone}", styles: const PosStyles(align: PosAlign.center));
    if (business.gstOrTin.isNotEmpty) {
      bytes += generator.text("GSTIN: ${business.gstOrTin}", styles: const PosStyles(align: PosAlign.center, bold: true));
    }
    if (business.receiptHeader.isNotEmpty) {
      final headerLines = business.receiptHeader.split('\n');
      for (var line in headerLines) {
        bytes += generator.text(line, styles: const PosStyles(align: PosAlign.center));
      }
    }

    bytes += generator.hr();

    // Invoice Meta
    bytes += generator.text("Invoice: ${invoice.invoiceNumber}");
    bytes += generator.text("Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(invoice.dateTime)}");
    if (invoice.customerPhone.isNotEmpty) {
      bytes += generator.text("Customer: ${invoice.customerPhone}");
    }
    bytes += generator.text("Payment: ${invoice.paymentMethod} - ${invoice.paymentStatus}");

    bytes += generator.hr();

    // Table Header
    // 58mm width uses 32 characters per line, 80mm uses 48 characters.
    // Columns: Name (width 6), Qty (width 2), Total (width 4)
    if (paperWidth == 80) {
      bytes += generator.row([
        PosColumn(text: 'Item Description', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
        PosColumn(text: 'Price', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
        PosColumn(text: 'Total', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    } else {
      bytes += generator.row([
        PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(align: PosAlign.right, bold: true)),
        PosColumn(text: 'Total', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }

    bytes += generator.hr();

    // Items list
    for (var item in invoice.items) {
      if (paperWidth == 80) {
        bytes += generator.row([
          PosColumn(text: item.productName, width: 6),
          PosColumn(text: item.quantity.toString(), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: item.price.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: item.subtotal.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right)),
        ]);
      } else {
        bytes += generator.row([
          PosColumn(text: item.productName, width: 6),
          PosColumn(text: item.quantity.toString(), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: item.subtotal.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
    }

    bytes += generator.hr();

    // Totals Block
    final String currencySym = business.currency;

    bytes += generator.row([
      PosColumn(text: 'Subtotal:', width: 6),
      PosColumn(
        text: '$currencySym${invoice.totalAmount.toStringAsFixed(2)}',
        width: paperWidth == 80 ? 6 : 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    if (invoice.discountAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount:', width: 6),
        PosColumn(
          text: '-$currencySym${invoice.discountAmount.toStringAsFixed(2)}',
          width: paperWidth == 80 ? 6 : 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (invoice.taxAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Tax / GST:', width: 6),
        PosColumn(
          text: '+$currencySym${invoice.taxAmount.toStringAsFixed(2)}',
          width: paperWidth == 80 ? 6 : 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.row([
      PosColumn(text: 'Grand Total:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: '$currencySym${invoice.grandTotal.toStringAsFixed(2)}',
        width: paperWidth == 80 ? 6 : 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.hr();

    // Print UPI QR code if config is present and grand total > 0
    if (business.upiId.isNotEmpty && invoice.grandTotal > 0) {
      bytes += generator.text("SCAN TO PAY VIA UPI", styles: const PosStyles(align: PosAlign.center, bold: true));
      
      final String nameEncoded = Uri.encodeComponent(business.name);
      final String noteEncoded = Uri.encodeComponent("Invoice ${invoice.invoiceNumber}");
      final String upiUrl = "upi://pay?pa=${business.upiId}&pn=$nameEncoded&am=${invoice.grandTotal.toStringAsFixed(2)}&cu=INR&tn=$noteEncoded";
      
      try {
        bytes += generator.qrcode(upiUrl, size: QRSize.size4);
      } catch (e) {
        debugPrint("Error generating QR code for receipt: $e");
      }
      bytes += generator.text(business.upiId, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();
    }

    // Footer
    if (business.receiptFooter.isNotEmpty) {
      final footerLines = business.receiptFooter.split('\n');
      for (var line in footerLines) {
        bytes += generator.text(line, styles: const PosStyles(align: PosAlign.center));
      }
    } else {
      bytes += generator.text("Thank You for Shopping!", styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("Please visit again", styles: const PosStyles(align: PosAlign.center));
    }

    // Feed paper & Cut
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
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

    if (_activePrinter!.type == 'bluetooth') {
      try {
        // Ensure connected
        final status = await PrintBluetoothThermal.connectionStatus;
        if (!status) {
          final connected = await connectBluetooth(_activePrinter!.address);
          if (!connected) return false;
        }

        final bool result = await PrintBluetoothThermal.writeBytes(bytes);
        return result;
      } catch (e) {
        debugPrint("Error writing bluetooth print bytes: $e");
        return false;
      }
    } else if (_activePrinter!.type == 'network') {
      // Wi-Fi Printing
      try {
        final addressParts = _activePrinter!.address.split(':');
        final String ip = addressParts[0];
        final int port = addressParts.length > 1 ? int.parse(addressParts[1]) : 9100;

        final Socket socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 4));
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
}
