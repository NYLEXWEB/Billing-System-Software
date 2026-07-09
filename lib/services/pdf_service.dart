import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/business.dart';

class PdfService {
  static Future<Uint8List> buildInvoicePdf({
    required Invoice invoice,
    required Business business,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final String currencySym = business.currency;

    // Build UPI Payment URL
    final String nameEncoded = Uri.encodeComponent(business.name);
    final String noteEncoded = Uri.encodeComponent("Invoice ${invoice.invoiceNumber}");
    final String upiUrl = "upi://pay?pa=${business.upiId}&pn=$nameEncoded&am=${invoice.grandTotal.toStringAsFixed(2)}&cu=INR&tn=$noteEncoded";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Row (Business Details & Title)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        business.name.toUpperCase(),
                        style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blueGrey900),
                      ),
                      pw.SizedBox(height: 4),
                      if (business.address.isNotEmpty)
                        pw.Text(business.address, style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                      pw.Text("Phone: ${business.phone}", style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                      pw.Text("Email: ${business.email}", style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                      if (business.gstOrTin.isNotEmpty)
                        pw.Text("GSTIN: ${business.gstOrTin}", style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey800)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "INVOICE",
                        style: pw.TextStyle(font: fontBold, fontSize: 28, color: PdfColors.blueAccent),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text("Invoice No: ${invoice.invoiceNumber}", style: pw.TextStyle(font: fontBold, fontSize: 12)),
                      pw.Text("Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(invoice.dateTime)}", style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                      pw.Text("Payment: ${invoice.paymentMethod} (${invoice.paymentStatus})", style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.green700)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 24),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),

              // Customer / Billing to
              if (invoice.customerPhone.isNotEmpty) ...[
                pw.Text("BILL TO:", style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey600)),
                pw.Text("Customer Mobile: ${invoice.customerPhone}", style: pw.TextStyle(font: fontBold, fontSize: 12)),
                pw.SizedBox(height: 20),
              ],

              // Items Table
              pw.Table(
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),  // S.No
                  1: const pw.FlexColumnWidth(3),     // Name
                  2: const pw.FixedColumnWidth(80),  // Price
                  3: const pw.FixedColumnWidth(60),  // Qty
                  4: const pw.FixedColumnWidth(100), // Total
                },
                children: [
                  // Table Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: pw.Text("S.No", style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey900)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: pw.Text("Product / Description", style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey900)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: pw.Text("Unit Price", style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey900), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: pw.Text("Qty", style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey900), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: pw.Text("Subtotal", style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey900), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),

                  // Table Data Rows
                  ...List.generate(invoice.items.length, (index) {
                    final item = invoice.items[index];
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: pw.Text((index + 1).toString(), style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: pw.Text(item.productName, style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: pw.Text("$currencySym${item.price.toStringAsFixed(2)}", style: pw.TextStyle(font: fontRegular, fontSize: 10), textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: pw.Text(item.quantity.toString(), style: pw.TextStyle(font: fontRegular, fontSize: 10), textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: pw.Text("$currencySym${item.subtotal.toStringAsFixed(2)}", style: pw.TextStyle(font: fontBold, fontSize: 10), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              // Totals & Payment QR Grid
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left side - UPI QR Payment
                  business.upiId.isNotEmpty && invoice.grandTotal > 0
                      ? pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("SCAN TO PAY VIA UPI", style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700)),
                            pw.SizedBox(height: 6),
                            pw.Container(
                              width: 90,
                              height: 90,
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: upiUrl,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(business.upiId, style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600)),
                          ],
                        )
                      : pw.SizedBox(),

                  // Right side - Calculations
                  pw.Container(
                    width: 220,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("Subtotal:", style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                            pw.Text("$currencySym${invoice.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        if (invoice.discountAmount > 0) ...[
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text("Discount:", style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.red700)),
                              pw.Text("-$currencySym${invoice.discountAmount.toStringAsFixed(2)}", style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.red700)),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                        ],
                        if (invoice.taxAmount > 0) ...[
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text("Tax / GST:", style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                              pw.Text("+$currencySym${invoice.taxAmount.toStringAsFixed(2)}", style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                        ],
                        pw.Divider(color: PdfColors.grey300),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("Grand Total:", style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blueGrey900)),
                            pw.Text(
                              "$currencySym${invoice.grandTotal.toStringAsFixed(2)}",
                              style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blueAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Terms & Sign-off
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Column(
                  children: [
                    pw.Text("Thank you for your business!", style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text("This is a computer generated invoice and requires no signature.", style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  static Future<void> generateAndShareInvoicePdf({
    required Invoice invoice,
    required Business business,
  }) async {
    final pdfBytes = await buildInvoicePdf(invoice: invoice, business: business);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }
}
