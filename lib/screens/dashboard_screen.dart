import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/business_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/product_provider.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import 'invoice_detail_sheet.dart';

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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good morning ☀️";
    } else if (hour < 17) {
      return "Good afternoon 🌤️";
    } else {
      return "Good evening 🌙";
    }
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0, // We build our own premium custom header in the body
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await productProvider.loadProducts();
          await invoiceProvider.loadInvoices();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome / Shop Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shop?.name ?? "EasyToBill Store",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15), width: 1.5),
                    ),
                    child: IconButton(
                      icon: Icon(
                        lowStockItems.isNotEmpty ? Icons.warning_amber_rounded : Icons.storefront_rounded,
                        color: lowStockItems.isNotEmpty ? Colors.orange : theme.colorScheme.primary,
                        size: 24,
                      ),
                      onPressed: () {
                        if (lowStockItems.isNotEmpty) {
                          _showLowStockDialog(context, lowStockItems);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Welcome to ${shop?.name ?? 'EasyToBill'}! All systems running smooth."),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. KPI Cards Grid
              _buildKpiGrid(currency, salesTodayVal, ordersTodayVal, salesMonthVal, theme),
              const SizedBox(height: 24),

              // 3. Stock Warning Banner
              if (lowStockItems.isNotEmpty) ...[
                _buildStockWarningCard(lowStockItems.length, theme),
                const SizedBox(height: 24),
              ],

              // 4. Sales Chart (Last 7 Days)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Sales Analytics",
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.4),
                  ),
                  Text(
                    "Last 7 Days",
                    style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSalesChart(invoiceProvider.last7DaysSales, currency, theme),
              const SizedBox(height: 28),

              // 5. Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Transactions",
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.4),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Navigate to the 'Invoices' tab on the bottom menu to view all records"),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    },
                    child: const Text(
                      "View All",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 6),
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
              title: "Today's Revenue",
              value: "$currency${salesToday.toStringAsFixed(2)}",
              trendText: "Today",
              icon: Icons.analytics_rounded,
              accentColor: const Color(0xFF2563EB), // Cobalt Blue
              theme: theme,
              width: cardWidth,
            ),
            _buildStatCard(
              title: "Today's Orders",
              value: ordersToday.toString(),
              trendText: "Active",
              icon: Icons.shopping_basket_rounded,
              accentColor: const Color(0xFF8B5CF6), // Purple
              theme: theme,
              width: cardWidth,
            ),
            _buildStatCard(
              title: "Monthly Volume",
              value: "$currency${salesMonth.toStringAsFixed(2)}",
              trendText: "This Month",
              icon: Icons.auto_graph_rounded,
              accentColor: const Color(0xFF10B981), // Emerald Green
              theme: theme,
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
    required String trendText,
    required IconData icon,
    required Color accentColor,
    required ThemeData theme,
    required double width,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.05 : 0.02),
            blurRadius: 12,
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trendText,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockWarningCard(int count, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Low Stock Catalog Alert",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange),
                ),
                const SizedBox(height: 3),
                Text(
                  "$count products have fallen below minimum thresholds.",
                  style: TextStyle(color: theme.hintColor, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final productProvider = Provider.of<ProductProvider>(context, listen: false);
              _showLowStockDialog(context, productProvider.lowStockProducts);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.withOpacity(0.12),
              foregroundColor: Colors.orange,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("View", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(List<DailySalesPoint> points, String currency, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (points.isEmpty || points.every((p) => p.amount == 0.0)) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_rounded, color: theme.hintColor.withOpacity(0.4), size: 40),
              const SizedBox(height: 10),
              Text(
                "No sales data recorded in the last 7 days.",
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
      );
    }

    final double maxVal = points.fold(0.0, (max, p) => p.amount > max ? p.amount : max);
    final double maxY = maxVal == 0 ? 100 : maxVal * 1.15;

    return Container(
      height: 220,
      padding: const EdgeInsets.only(top: 24, right: 20, left: 12, bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.04 : 0.01),
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
                  "$currency${rod.toY.toStringAsFixed(0)}",
                  TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 12),
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
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        points[index].label,
                        style: TextStyle(color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
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
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.7),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: theme.colorScheme.primary.withOpacity(0.04),
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
        height: 120,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded, color: theme.hintColor.withOpacity(0.4), size: 36),
              const SizedBox(height: 8),
              Text(
                "No transactions recorded yet.",
                style: TextStyle(color: theme.hintColor, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: list.map((invoice) {
        final isCash = invoice.paymentMethod == 'CASH';
        final isUpi = invoice.paymentMethod == 'UPI';

        Color paymentColor;
        IconData paymentIcon;
        if (isCash) {
          paymentColor = const Color(0xFF10B981); // Emerald Green
          paymentIcon = Icons.payments_rounded;
        } else if (isUpi) {
          paymentColor = Colors.blueAccent;
          paymentIcon = Icons.qr_code_2_rounded;
        } else {
          paymentColor = Colors.purple;
          paymentIcon = Icons.contactless_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: paymentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(paymentIcon, color: paymentColor, size: 22),
            ),
            title: Row(
              children: [
                Text(
                  invoice.invoiceNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                if (invoice.customerPhone.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      invoice.customerPhone,
                      style: TextStyle(fontSize: 9, color: theme.hintColor, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                DateFormat('dd MMM yyyy • hh:mm a').format(invoice.dateTime),
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$currency${invoice.grandTotal.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: -0.4),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: invoice.paymentStatus == 'PAID'
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    invoice.paymentStatus,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: invoice.paymentStatus == 'PAID' ? const Color(0xFF10B981) : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () => _showInvoiceDetail(context, invoice),
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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text("Low Stock Catalog", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: items.isEmpty
              ? const Center(child: Text("No items are currently low on stock."))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text("SKU: ${item.barcode}", style: const TextStyle(fontSize: 12)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: item.stockQuantity == 0 ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${item.stockQuantity} Left",
                            style: TextStyle(
                              color: item.stockQuantity == 0 ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
