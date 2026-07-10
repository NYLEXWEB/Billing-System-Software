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
  String _activeFilter = 'all'; // 'all', 'today', 'yesterday', '7days', 'month', 'custom'

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

  void _handleFilterChange(String id) async {
    if (id == 'custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        initialDateRange: _selectedDateRange,
      );
      if (picked != null) {
        setState(() {
          _activeFilter = 'custom';
          _selectedDateRange = picked;
        });
      }
    } else {
      setState(() {
        _activeFilter = id;
        if (id == 'all') {
          _selectedDateRange = null;
        } else if (id == 'today') {
          _selectedDateRange = DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now(),
          );
        } else if (id == 'yesterday') {
          final y = DateTime.now().subtract(const Duration(days: 1));
          _selectedDateRange = DateTimeRange(start: y, end: y);
        } else if (id == '7days') {
          _selectedDateRange = DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 6)),
            end: DateTime.now(),
          );
        } else if (id == 'month') {
          _selectedDateRange = DateTimeRange(
            start: DateTime(DateTime.now().year, DateTime.now().month, 1),
            end: DateTime.now(),
          );
        }
      });
    }
  }

  Widget _buildQuickFilterBar(bool isDark) {
    final filters = [
      {'id': 'all', 'label': 'All Time'},
      {'id': 'today', 'label': 'Today'},
      {'id': 'yesterday', 'label': 'Yesterday'},
      {'id': '7days', 'label': 'Last 7 Days'},
      {'id': 'month', 'label': 'This Month'},
      {'id': 'custom', 'label': 'Custom'},
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _activeFilter == filter['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () => _handleFilterChange(filter['id']!),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Center(
                  child: Text(
                    filter['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Sales Reports & Logs", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        actions: [
          if (_selectedDateRange != null || _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded, color: Colors.redAccent),
              tooltip: "Clear Filters",
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                  _searchQuery = '';
                  _activeFilter = 'all';
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
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: "Search Invoice or Customer Phone...",
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // 2. Quick filters
          _buildQuickFilterBar(isDark),

          // 3. Date label if selected
          if (_selectedDateRange != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Selected Range: ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 4. Quick aggregate summaries
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: "Selected Sales",
                    value: "$currency${totalSales.toStringAsFixed(2)}",
                    colors: [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                    icon: Icons.currency_rupee_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    title: "Orders Count",
                    value: totalOrders.toString(),
                    colors: [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
                    icon: Icons.receipt_long_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

          // 5. Payment distribution graph
          if (filteredInvoices.isNotEmpty) ...[
            _buildPaymentMethodChart(filteredInvoices, currency, isDark),
            const SizedBox(height: 16),
          ],

          // 6. Audit Log list of Invoices
          Expanded(
            child: filteredInvoices.isEmpty
                ? const Center(
                    child: Text(
                      "No invoice logs found matching filters",
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filteredInvoices.length,
                    itemBuilder: (context, index) {
                      final invoice = filteredInvoices[index];
                      return _buildInvoiceListItem(
                        invoice: invoice,
                        currency: currency,
                        isDark: isDark,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required List<Color> colors,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 80,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChart(List<Invoice> list, String currency, bool isDark) {
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Payment Method Split",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: -0.2),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: [
                      if (cashTotal > 0)
                        PieChartSectionData(
                          value: cashTotal,
                          color: const Color(0xFF10B981),
                          radius: 14,
                          showTitle: false,
                        ),
                      if (upiTotal > 0)
                        PieChartSectionData(
                          value: upiTotal,
                          color: const Color(0xFF3B82F6),
                          radius: 14,
                          showTitle: false,
                        ),
                      if (cardTotal > 0)
                        PieChartSectionData(
                          value: cardTotal,
                          color: const Color(0xFFF59E0B),
                          radius: 14,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                      label: "Cash",
                      amount: cashTotal,
                      percent: (cashTotal / grandTotal) * 100,
                      color: const Color(0xFF10B981),
                      currency: currency,
                    ),
                    const SizedBox(height: 10),
                    _buildLegendItem(
                      label: "UPI QR",
                      amount: upiTotal,
                      percent: (upiTotal / grandTotal) * 100,
                      color: const Color(0xFF3B82F6),
                      currency: currency,
                    ),
                    const SizedBox(height: 10),
                    _buildLegendItem(
                      label: "Card / Other",
                      amount: cardTotal,
                      percent: (cardTotal / grandTotal) * 100,
                      color: const Color(0xFFF59E0B),
                      currency: currency,
                    ),
                  ],
                ),
              ),
            ],
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
    required String currency,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                "${percent.toStringAsFixed(1)}%",
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Text(
          "$currency${amount.toStringAsFixed(0)}",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInvoiceListItem({
    required Invoice invoice,
    required String currency,
    required bool isDark,
  }) {
    IconData icon;
    Color iconColor;
    if (invoice.paymentMethod == 'CASH') {
      icon = Icons.payments_outlined;
      iconColor = const Color(0xFF10B981);
    } else if (invoice.paymentMethod == 'UPI') {
      icon = Icons.qr_code_2_rounded;
      iconColor = const Color(0xFF3B82F6);
    } else {
      icon = Icons.credit_card_rounded;
      iconColor = const Color(0xFFF59E0B);
    }

    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(invoice.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => InvoiceDetailSheet(invoice: invoice),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (invoice.customerPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            "Phone: ${invoice.customerPhone}",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "$currency${invoice.grandTotal.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: invoice.paymentStatus.toUpperCase() == 'PAID'
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          invoice.paymentStatus,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: invoice.paymentStatus.toUpperCase() == 'PAID'
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
