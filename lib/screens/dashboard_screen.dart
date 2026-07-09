import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/business_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/product_provider.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import 'invoice_detail_sheet.dart'; // We'll create this helper next

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load products and invoices when entering dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).loadProducts();
      Provider.of<InvoiceProvider>(context, listen: false).loadInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = Provider.of<BusinessProvider>(context);
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    final shop = businessProvider.business;
    final currency = shop?.currency ?? '₹';

    final salesTodayVal = invoiceProvider.salesToday;
    final salesMonthVal = invoiceProvider.salesThisMonth;
    final ordersTodayVal = invoiceProvider.ordersTodayCount;
    final lowStockItems = productProvider.lowStockProducts;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shop?.name ?? "My Shop",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
        actions: [
          if (lowStockItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: IconButton(
                icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                onPressed: () {
                  _showLowStockDialog(context, lowStockItems);
                },
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await productProvider.loadProducts();
          await invoiceProvider.loadInvoices();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KPI Cards Grid
              _buildKpiGrid(currency, salesTodayVal, ordersTodayVal, salesMonthVal, theme),
              const SizedBox(height: 24),

              // 2. Stock Warning Card
              if (lowStockItems.isNotEmpty) _buildStockWarningCard(lowStockItems.length, theme),

              // 3. Sales Chart (Last 7 Days)
              Text(
                "Sales Analytics (Last 7 Days)",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildSalesChart(invoiceProvider.last7DaysSales, currency, theme),
              const SizedBox(height: 24),

              // 4. Recent Transactions List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Transactions",
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate/switch to Reports screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Open Reports tab to view all invoices")),
                      );
                    },
                    child: const Text("View All"),
                  )
                ],
              ),
              _buildRecentTransactions(invoiceProvider.invoices.take(5).toList(), currency, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(
    String currency,
    double salesToday,
    int ordersToday,
    double salesMonth,
    ThemeData theme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              title: "Today's Sales",
              value: "$currency${salesToday.toStringAsFixed(2)}",
              icon: Icons.currency_rupee,
              gradientColors: [Colors.blue.shade700, Colors.blue.shade500],
              width: cardWidth,
            ),
            _buildStatCard(
              title: "Today's Orders",
              value: ordersToday.toString(),
              icon: Icons.shopping_bag_outlined,
              gradientColors: [Colors.purple.shade700, Colors.purple.shade500],
              width: cardWidth,
            ),
            _buildStatCard(
              title: "Monthly Sales",
              value: "$currency${salesMonth.toStringAsFixed(2)}",
              icon: Icons.trending_up,
              gradientColors: [Colors.teal.shade700, Colors.teal.shade500],
              width: constraints.maxWidth, // Full width card
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStockWarningCard(int count, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Low Stock Warning",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                ),
                const SizedBox(height: 2),
                Text(
                  "$count products have fallen below their minimum stock threshold.",
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(List<DailySalesPoint> points, String currency, ThemeData theme) {
    if (points.isEmpty || points.every((p) => p.amount == 0.0)) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        ),
        child: Center(
          child: Text(
            "No sales data to display for the last 7 days.",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
        ),
      );
    }

    final double maxVal = points.fold(0.0, (max, p) => p.amount > max ? p.amount : max);
    final double maxY = maxVal == 0 ? 100 : maxVal * 1.2;

    return Container(
      height: 220,
      padding: const EdgeInsets.only(top: 24, right: 20, left: 8, bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: theme.colorScheme.primaryContainer,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "$currency${rod.toY.toStringAsFixed(2)}",
                  TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.toInt();
                  if (index >= 0 && index < points.length) {
                    return Text(
                      points[index].label,
                      style: TextStyle(color: theme.hintColor, fontSize: 11, fontWeight: FontWeight.w500),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(points.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: points[index].amount,
                  color: Colors.blueAccent,
                  width: 14,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: Colors.blueAccent.withOpacity(0.05),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(List<Invoice> list, String currency, ThemeData theme) {
    if (list.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            "No transactions recorded yet.",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
        ),
      );
    }

    return Column(
      children: list.map((invoice) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: invoice.paymentMethod == 'CASH'
                  ? Colors.green.shade50
                  : invoice.paymentMethod == 'UPI'
                      ? Colors.blue.shade50
                      : Colors.orange.shade50,
              child: Icon(
                invoice.paymentMethod == 'CASH'
                    ? Icons.money
                    : invoice.paymentMethod == 'UPI'
                        ? Icons.qr_code_scanner
                        : Icons.credit_card,
                color: invoice.paymentMethod == 'CASH'
                    ? Colors.green.shade700
                    : invoice.paymentMethod == 'UPI'
                        ? Colors.blue.shade700
                        : Colors.orange.shade700,
              ),
            ),
            title: Text(
              invoice.invoiceNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(DateFormat('dd MMM, hh:mm a').format(invoice.dateTime)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$currency${invoice.grandTotal.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: invoice.paymentStatus == 'PAID' ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    invoice.paymentStatus,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: invoice.paymentStatus == 'PAID' ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () {
              _showInvoiceDetail(context, invoice);
            },
          ),
        );
      }).toList(),
    );
  }

  void _showInvoiceDetail(BuildContext context, Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvoiceDetailSheet(invoice: invoice),
    );
  }

  void _showLowStockDialog(BuildContext context, List<Product> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text("Low Stock Catalog"),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Barcode: ${item.barcode}"),
                trailing: Text(
                  "${item.stockQuantity} Left",
                  style: TextStyle(
                    color: item.stockQuantity == 0 ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }
}
