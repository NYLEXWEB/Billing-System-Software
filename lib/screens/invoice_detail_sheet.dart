import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../providers/business_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/invoice_provider.dart';
// We'll create the PDF builder service next
import '../services/pdf_service.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Transaction Receipt",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 12),

          // Invoice Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      DateFormat('dd-MMM-yyyy hh:mm a').format(invoice.dateTime),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                    if (invoice.customerName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Customer: ${invoice.customerName}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ],
                    if (invoice.customerPhone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Mobile: ${invoice.customerPhone}",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: invoice.paymentStatus == 'PAID' ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  invoice.paymentStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: invoice.paymentStatus == 'PAID' ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),

          // Invoice Items List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: invoice.items.length,
              itemBuilder: (context, index) {
                final item = invoice.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              "${item.quantity} x $currency${item.price.toStringAsFixed(2)}",
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "$currency${item.subtotal.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),

          // Totals Block
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Subtotal"),
              Text("$currency${invoice.totalAmount.toStringAsFixed(2)}"),
            ],
          ),
          if (invoice.discountAmount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Discount"),
                Text("-$currency${invoice.discountAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red)),
              ],
            ),
          ],
          if (invoice.taxAmount > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tax / GST"),
                Text("+$currency${invoice.taxAmount.toStringAsFixed(2)}"),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Payment Method"),
              Text(
                invoice.paymentMethod.startsWith('SPLIT:')
                    ? _getSplitPaymentDisplay(invoice.paymentMethod)
                    : invoice.paymentMethod,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Grand Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                "$currency${invoice.grandTotal.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action Buttons
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
                  icon: const Icon(Icons.share),
                  label: const Text("Share PDF"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (shop == null) return;
                    final success = await printerProvider.printInvoice(invoice, shop);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? "Printing successful!" : "Printing failed. Check printer connection."),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.print),
                  label: const Text("Print Receipt"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          // Cancel button
          if (invoice.paymentStatus.toUpperCase() != 'CANCELLED')
            TextButton.icon(
              onPressed: () {
                _showCancelConfirmDialog(context, invoiceProvider);
              },
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              label: const Text("Cancel Invoice", style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "Invoice cancelled and stock replenished." : "Failed to cancel invoice."),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
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
