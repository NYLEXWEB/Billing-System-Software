import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import '../data/db_helper.dart';
import '../models/stock_movement.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<StockMovement> _movements = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() => _isLoading = true);
    try {
      final list = await DbHelper().getAllStockMovements();
      setState(() {
        _movements = list;
      });
    } catch (e) {
      debugPrint("Error loading movements: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Control & Logs", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMovements,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Quick Summary Header
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAdjustmentDialog(context, productProvider),
                          icon: const Icon(Icons.add_business_outlined),
                          label: const Text("New Stock Adjustment"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Stock Movements Ledger",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey),
                    ),
                  ),
                ),

                // Movement Logs List
                Expanded(
                  child: _movements.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off, size: 64, color: theme.hintColor.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              const Text("No inventory movements logged yet", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _movements.length,
                          itemBuilder: (context, index) {
                            final movement = _movements[index];
                            final isPositive = movement.quantity > 0;
                            final type = movement.type; // 'IN', 'OUT', 'SET'

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: type == 'IN'
                                      ? Colors.green.shade50
                                      : type == 'OUT'
                                          ? Colors.red.shade50
                                          : Colors.blue.shade50,
                                  child: Icon(
                                    type == 'IN'
                                        ? Icons.arrow_downward
                                        : type == 'OUT'
                                            ? Icons.arrow_upward
                                            : Icons.pin_drop,
                                    color: type == 'IN'
                                        ? Colors.green.shade700
                                        : type == 'OUT'
                                            ? Colors.red.shade700
                                            : Colors.blue.shade700,
                                  ),
                                ),
                                title: Text(
                                  movement.productName ?? "Product ID: ${movement.productId}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Reason: ${movement.reason}"),
                                    Text(
                                      DateFormat('dd MMM yyyy, hh:mm a').format(movement.dateTime),
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  "${isPositive ? '+' : ''}${movement.quantity}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: type == 'IN'
                                        ? Colors.green
                                        : type == 'OUT'
                                            ? Colors.red
                                            : Colors.blue,
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

  void _showAdjustmentDialog(BuildContext context, ProductProvider provider) {
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();

    Product? selectedProduct;
    String movementType = 'IN'; // 'IN', 'OUT', 'SET'

    // Filter products that have stock tracking enabled
    final trackedProducts = provider.products.where((p) => p.isTracked).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Stock Correction"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product select
                      DropdownButtonFormField<Product>(
                        value: selectedProduct,
                        decoration: const InputDecoration(labelText: "Select Tracked Product *"),
                        items: trackedProducts.map((p) {
                          return DropdownMenuItem<Product>(
                            value: p,
                            child: Text("${p.name} (Stock: ${p.stockQuantity})"),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedProduct = val),
                        validator: (v) => v == null ? "Product is required" : null,
                      ),
                      const SizedBox(height: 12),

                      // Adjustment Type Select
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Adjustment Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("Add (+)"),
                              selected: movementType == 'IN',
                              onSelected: (selected) {
                                if (selected) setDialogState(() => movementType = 'IN');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("Deduct (-)"),
                              selected: movementType == 'OUT',
                              onSelected: (selected) {
                                if (selected) setDialogState(() => movementType = 'OUT');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("Set (=)"),
                              selected: movementType == 'SET',
                              onSelected: (selected) {
                                if (selected) setDialogState(() => movementType = 'SET');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quantity input
                      TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: movementType == 'SET' ? "New Absolute Stock Level *" : "Quantity Count *",
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required";
                          final numVal = int.tryParse(v);
                          if (numVal == null || numVal <= 0) return "Must be a positive integer";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Reason input
                      TextFormField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: "Adjustment Reason / Reference *",
                          hintText: "e.g. Audit, damage, vendor delivery",
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? "Reason is required" : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate() || selectedProduct == null) return;

                    final qty = int.parse(quantityController.text);
                    final reason = reasonController.text.trim();

                    // Map quantity sign based on movement type
                    int adjustedQty = qty;
                    if (movementType == 'OUT') {
                      adjustedQty = -qty;
                    }

                    final success = await provider.adjustStock(
                      selectedProduct!.id!,
                      adjustedQty,
                      movementType,
                      reason,
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog
                      _loadMovements(); // Reload logs

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? "Stock adjusted successfully!" : "Adjustment failed."),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
