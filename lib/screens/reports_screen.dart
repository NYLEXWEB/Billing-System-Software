import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/invoice_provider.dart';
import '../providers/business_provider.dart';
import '../models/invoice.dart';
import 'invoice_detail_sheet.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InvoiceProvider>(context, listen: false).loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Invoice> _getFilteredInvoices(List<Invoice> allInvoices) {
    return allInvoices.where((invoice) {
      // 1. Search Query Filter (matches Invoice ID or Customer Phone)
      final matchesSearch = invoice.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          invoice.customerPhone.contains(_searchQuery);

      // 2. Date Range Filter
      bool matchesDate = true;
      if (_selectedDateRange != null) {
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        matchesDate = invoice.dateTime.isAfter(start) && invoice.dateTime.isBefore(end);
      }

      return matchesSearch && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final businessProvider = Provider.of<BusinessProvider>(context);
    final currency = businessProvider.business?.currency ?? '₹';

    final filteredInvoices = _getFilteredInvoices(invoiceProvider.invoices);
    
    // Aggregate calculations
    final totalSales = filteredInvoices.fold(0.0, (sum, inv) => sum + inv.grandTotal);
    final totalOrders = filteredInvoices.length;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Reports & Logs", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            tooltip: "Filter by Date",
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                initialDateRange: _selectedDateRange,
              );
              if (picked != null) {
                setState(() {
                  _selectedDateRange = picked;
                });
              }
            },
          ),
          if (_selectedDateRange != null || _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all, color: Colors.redAccent),
              tooltip: "Clear Filters",
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Box
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search Invoice Number or Customer Mobile...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // 2. Date label if selected
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text(
                    "Date Range: ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}",
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
            ),

          // 3. Quick aggregate summaries
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: "Selected Sales",
                    value: "$currency${totalSales.toStringAsFixed(2)}",
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    title: "Orders Count",
                    value: totalOrders.toString(),
                    color: Colors.purpleAccent,
                  ),
                ),
              ],
            ),
          ),

          // 4. Payment distribution graph
          if (filteredInvoices.isNotEmpty) ...[
            _buildPaymentMethodChart(filteredInvoices, theme),
            const SizedBox(height: 12),
          ],

          // 5. Audit Log list of Invoices
          Expanded(
            child: filteredInvoices.isEmpty
                ? const Center(child: Text("No invoice logs found matching filters"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filteredInvoices.length,
                    itemBuilder: (context, index) {
                      final invoice = filteredInvoices[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              title: Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(DateFormat('dd MMM, hh:mm a').format(invoice.dateTime)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "$currency${invoice.grandTotal.toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    "${invoice.paymentMethod} - ${invoice.paymentStatus}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: invoice.paymentMethod == 'CASH' ? Colors.green : Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => InvoiceDetailSheet(invoice: invoice),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required Color color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChart(List<Invoice> list, ThemeData theme) {
    // Group payment method totals
    double cashTotal = 0;
    double upiTotal = 0;
    double cardTotal = 0;

    for (var inv in list) {
      if (inv.paymentMethod == 'CASH') {
        cashTotal += inv.grandTotal;
      } else if (inv.paymentMethod == 'UPI') {
        upiTotal += inv.grandTotal;
      } else {
        cardTotal += inv.grandTotal;
      }
    }

    final double grandTotal = cashTotal + upiTotal + cardTotal;
    if (grandTotal == 0) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Pie chart
          SizedBox(
            width: 110,
            height: 110,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                sections: [
                  if (cashTotal > 0)
                    PieChartSectionData(
                      value: cashTotal,
                      color: Colors.green,
                      radius: 12,
                      showTitle: false,
                    ),
                  if (upiTotal > 0)
                    PieChartSectionData(
                      value: upiTotal,
                      color: Colors.blue,
                      radius: 12,
                      showTitle: false,
                    ),
                  if (cardTotal > 0)
                    PieChartSectionData(
                      value: cardTotal,
                      color: Colors.orange,
                      radius: 12,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Legend labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Payment Channels", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                _buildLegendItem(label: "Cash", amount: cashTotal, percent: (cashTotal / grandTotal) * 100, color: Colors.green),
                const SizedBox(height: 4),
                _buildLegendItem(label: "UPI QR", amount: upiTotal, percent: (upiTotal / grandTotal) * 100, color: Colors.blue),
                const SizedBox(height: 4),
                _buildLegendItem(label: "Card logs", amount: cardTotal, percent: (cardTotal / grandTotal) * 100, color: Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required double amount,
    required double percent,
    required Color color,
  }) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text(
          "₹${amount.toStringAsFixed(0)} (${percent.toStringAsFixed(1)}%)",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
