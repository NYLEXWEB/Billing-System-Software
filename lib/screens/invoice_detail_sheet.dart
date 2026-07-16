import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../providers/business_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/product_provider.dart';
import '../services/pdf_service.dart';
import '../widgets/app_toast.dart';

class InvoiceDetailSheet extends StatelessWidget {
  final Invoice invoice;

  const InvoiceDetailSheet({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final businessProvider = Provider.of<BusinessProvider>(context);
    final printerProvider = Provider.of<PrinterProvider>(context);
    final invoiceProvider = Provider.of<InvoiceProvider>(context);

    final shop = businessProvider.business;
    final currency = shop?.currency ?? '₹';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isCancelled = invoice.paymentStatus.toUpperCase() == 'CANCELLED';

    // Status Badge Styling
    Color badgeBgColor;
    Color badgeTextColor;
    IconData statusIcon;
    if (isCancelled) {
      badgeBgColor = const Color(0xFFFEF2F2);
      badgeTextColor = const Color(0xFFEF4444);
      statusIcon = Icons.cancel_outlined;
    } else if (invoice.paymentStatus.toUpperCase() == 'PAID') {
      badgeBgColor = const Color(0xFFECFDF5);
      badgeTextColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_outline_rounded;
    } else {
      badgeBgColor = const Color(0xFFFFFBEB);
      badgeTextColor = const Color(0xFFF59E0B);
      statusIcon = Icons.error_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Physical Receipt Container
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Receipt Header Block
                    Container(
                      color: isDark ? const Color(0xFF334155).withOpacity(0.3) : const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: shop?.logoPath != null && shop!.logoPath!.isNotEmpty && File(shop.logoPath!).existsSync()
                                ? CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.transparent,
                                    backgroundImage: FileImage(File(shop.logoPath!)),
                                  )
                                : const CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.transparent,
                                    child: Icon(Icons.receipt_long_rounded, color: Colors.blueAccent, size: 28),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            shop?.name.toUpperCase() ?? 'BUSINESS RECEIPT',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (shop?.phone.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              "Ph: ${shop!.phone}",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: badgeBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: badgeTextColor.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: badgeTextColor, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  invoice.paymentStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: badgeTextColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Side perforation notches line
                    _buildNotchedPerforation(isDark),

                    // Receipt Info (Invoice No, DateTime, Customer)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "INVOICE NO:",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                invoice.invoiceNumber,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "DATE & TIME:",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                DateFormat('dd-MMM-yyyy hh:mm a').format(invoice.dateTime),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (invoice.customerName.isNotEmpty || invoice.customerPhone.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const DottedLine(color: Color(0xFFE2E8F0), height: 1),
                            const SizedBox(height: 10),
                            Text(
                              "CUSTOMER DETAILS",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (invoice.customerName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2.0),
                                child: Text(
                                  invoice.customerName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            if (invoice.customerPhone.isNotEmpty)
                              Text(
                                "Mobile: ${invoice.customerPhone}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),

                    // Separator
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: DottedLine(color: Color(0xFFE2E8F0), height: 1),
                    ),

                    // Items List Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "ITEMS",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          Text(
                            "AMOUNT",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Items List
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: invoice.items.length,
                        itemBuilder: (context, index) {
                          final item = invoice.items[index];
                          final productProvider = Provider.of<ProductProvider>(context, listen: false);
                          final matchedProduct = productProvider.products.firstWhere(
                            (p) => p.id == item.productId,
                            orElse: () => Product(id: -1, name: '', barcode: '', price: 0.0),
                          );
                          final hasImg = matchedProduct.id != -1 &&
                              matchedProduct.imagePath != null &&
                              matchedProduct.imagePath!.isNotEmpty &&
                              File(matchedProduct.imagePath!).existsSync();

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasImg) ...[
                                  Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.only(right: 8, top: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      image: DecorationImage(
                                        image: FileImage(File(matchedProduct.imagePath!)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      Text(
                                        "${item.quantity} x $currency${item.price.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "$currency${item.subtotal.toStringAsFixed(2)}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Separator
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: DottedLine(color: Color(0xFFE2E8F0), height: 1),
                    ),

                    // Pricing Totals Block
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Column(
                        children: [
                          _buildSummaryRow("Subtotal", "$currency${invoice.totalAmount.toStringAsFixed(2)}", isDark),
                          if (invoice.discountAmount > 0) ...[
                            const SizedBox(height: 6),
                            _buildSummaryRow("Discount", "-$currency${invoice.discountAmount.toStringAsFixed(2)}", isDark, isDiscount: true),
                          ],
                          if (invoice.taxAmount > 0) ...[
                            const SizedBox(height: 6),
                            _buildSummaryRow("Tax / GST", "+$currency${invoice.taxAmount.toStringAsFixed(2)}", isDark),
                          ],
                          const SizedBox(height: 8),
                          const DottedLine(color: Color(0xFFE2E8F0), height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "GRAND TOTAL",
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                              ),
                              Text(
                                "$currency${invoice.grandTotal.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "PAYMENT METHOD",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                invoice.paymentMethod.startsWith('SPLIT:')
                                    ? _getSplitPaymentDisplay(invoice.paymentMethod)
                                    : invoice.paymentMethod,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Perforation notches bottom
                    _buildNotchedPerforation(isDark),

                    // Barcode & Footer
                    Container(
                      color: isDark ? const Color(0xFF334155).withOpacity(0.1) : const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          const BarcodeWidget(),
                          const SizedBox(height: 6),
                          Text(
                            "Thank you for your business!",
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Share & Print Actions Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (shop == null) return;
                      await PdfService.generateAndShareInvoicePdf(
                        invoice: invoice,
                        business: shop,
                      );
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("Share PDF"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      foregroundColor: Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (shop == null) return;
                      final success = await printerProvider.printInvoice(invoice, shop);
                      if (context.mounted) {
                        if (success) {
                          AppToast.showSuccess(context, "Receipt printed successfully!");
                        } else {
                          AppToast.showError(context, "Printing failed. Check printer connection.");
                        }
                      }
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text("Print Receipt"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Cancel Invoice Action Button
            if (invoice.paymentStatus.toUpperCase() != 'CANCELLED')
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: TextButton.icon(
                  onPressed: () {
                    _showCancelConfirmDialog(context, invoiceProvider);
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                  label: const Text(
                    "Cancel Invoice",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotchedPerforation(bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: DottedLine(color: Color(0xFFCBD5E1), height: 1),
        ),
        Positioned(
          left: -12,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: -12,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String title, String value, bool isDark, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: isDiscount ? Colors.red : null,
          ),
        ),
      ],
    );
  }

  void _showCancelConfirmDialog(BuildContext context, InvoiceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Invoice?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "Are you sure you want to cancel this invoice?\n\n"
          "This will automatically replenish inventory stock levels for all items in this invoice and mark the transaction status as CANCELLED. This action cannot be undone."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No, Keep It"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close sheet
              final success = await provider.deleteInvoice(invoice.id!);
              if (context.mounted) {
                if (success) {
                  AppToast.showSuccess(context, "Invoice cancelled and stock replenished.");
                } else {
                  AppToast.showError(context, "Failed to cancel invoice.");
                }
              }
            },
            child: const Text("Cancel Invoice"),
          ),
        ],
      ),
    );
  }

  String _getSplitPaymentDisplay(String paymentMethod) {
    if (!paymentMethod.startsWith('SPLIT:')) return paymentMethod;
    final parts = paymentMethod.replaceFirst('SPLIT:', '').split(';');
    List<String> list = [];
    for (var part in parts) {
      final kv = part.split('=');
      if (kv.length == 2) {
        list.add("${kv[0]}: ₹${kv[1]}");
      }
    }
    return list.join(" + ");
  }
}

class DottedLine extends StatelessWidget {
  final double height;
  final Color color;

  const DottedLine({
    super.key,
    this.height = 1,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

class BarcodeWidget extends StatelessWidget {
  const BarcodeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(40, (index) {
          final width = (index % 3 == 0) ? 3.0 : ((index % 5 == 0) ? 1.0 : 1.5);
          final showBar = index % 4 != 0;
          return Container(
            width: width,
            color: showBar ? const Color(0xFF94A3B8) : Colors.transparent,
          );
        }),
      ),
    );
  }
}
