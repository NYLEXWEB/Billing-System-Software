import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../providers/business_provider.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/invoice_provider.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../data/db_helper.dart';
import 'barcode_scanner_screen.dart'; // We'll create this next
import 'invoice_detail_sheet.dart';

class PosBillingScreen extends StatefulWidget {
  const PosBillingScreen({super.key});

  @override
  State<PosBillingScreen> createState() => _PosBillingScreenState();
}

class _PosBillingScreenState extends State<PosBillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<Product> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, List<Product> allProducts) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final q = query.toLowerCase().trim();
    final results = allProducts.where((p) {
      return p.name.toLowerCase().contains(q) || p.barcode.contains(q);
    }).toList();

    setState(() {
      _searchResults = results;
      _isSearching = true;
    });
  }

  void _addToCart(Product product, CartProvider cart) {
    final success = cart.addItem(product);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Insufficient stock for ${product.name}!"),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // Clear search
      _searchController.clear();
      _searchFocusNode.unfocus();
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  String _generateInvoiceNumber() {
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final rand = Random().nextInt(900) + 100; // 3 digit random
    return "INV-$dateStr-$rand";
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = Provider.of<BusinessProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final invoiceProvider = Provider.of<InvoiceProvider>(context);

    final shop = businessProvider.business;
    final currency = shop?.currency ?? '₹';
    final allProducts = productProvider.products;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("POS Checkout", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 28),
            tooltip: "Scan Barcode",
            onPressed: () async {
              final String? barcode = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
              );

              if (barcode != null && barcode.isNotEmpty) {
                // Find product by barcode
                final product = allProducts.firstWhere(
                  (p) => p.barcode == barcode,
                  orElse: () => Product(id: -1, name: '', barcode: '', price: 0.0),
                );

                if (product.id != -1) {
                  _addToCart(product, cartProvider);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Barcode '$barcode' not found in inventory!"),
                        action: SnackBarAction(
                          label: "Create",
                          onPressed: () {
                            // Can jump to catalog creation (user option)
                          },
                        ),
                      ),
                    );
                  }
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            tooltip: "Clear Cart",
            onPressed: () {
              if (cartProvider.items.isNotEmpty) {
                cartProvider.clear();
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Product Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (val) => _onSearchChanged(val, allProducts),
              decoration: InputDecoration(
                hintText: "Search by Name, SKU or Barcode...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('', allProducts);
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // 2. Search Results Panel or Cart Panel
          Expanded(
            child: _isSearching
                ? _buildSearchResults(cartProvider)
                : _buildCartView(cartProvider, currency, theme),
          ),

          // 3. Checkout Calculations & Details bottom section
          if (cartProvider.items.isNotEmpty && !_isSearching)
            _buildCheckoutSection(cartProvider, invoiceProvider, shop, currency, theme),
        ],
      ),
    );
  }

  Widget _buildSearchResults(CartProvider cart) {
    if (_searchResults.isEmpty) {
      return const Center(child: Text("No items match your search"));
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return ListTile(
          title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Price: ${product.price} | Stock: ${product.isTracked ? product.stockQuantity : 'Unlimited'}"),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
            onPressed: () => _addToCart(product, cart),
          ),
          onTap: () => _addToCart(product, cart),
        );
      },
    );
  }

  Widget _buildCartView(CartProvider cart, String currency, ThemeData theme) {
    if (cart.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 72, color: theme.hintColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              "Your checkout cart is empty",
              style: TextStyle(color: theme.hintColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: cart.items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = cart.items[index];
        // Fetch corresponding product for stock validations
        final productProvider = Provider.of<ProductProvider>(context, listen: false);
        final product = productProvider.products.firstWhere((p) => p.id == item.productId);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      "$currency${item.price.toStringAsFixed(2)} each",
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),

              // Quantity selectors
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    onPressed: () {
                      cart.updateQuantity(item.productId, item.quantity - 1, product);
                    },
                  ),
                  Text(
                    item.quantity.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    onPressed: () {
                      final ok = cart.updateQuantity(item.productId, item.quantity + 1, product);
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Insufficient stock quantity!"), backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Subtotal
              Text(
                "$currency${item.subtotal.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),

              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => cart.removeItem(item.productId),
              ),
            ],
          ),
        );
      },
    );
  }  Widget _buildCheckoutSection(
    CartProvider cart,
    InvoiceProvider invoiceProvider,
    dynamic shop,
    String currency,
    ThemeData theme,
  ) {
    final hasDiscount = cart.discountAmount > 0;
    final hasTax = cart.taxRate > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtotal row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Subtotal (${cart.items.length} items)",
                  style: TextStyle(color: theme.hintColor, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  "$currency${cart.totalAmount.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action Pills for Discount and Tax
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showDiscountDialog(cart),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: hasDiscount 
                            ? Colors.red.withOpacity(0.08) 
                            : theme.dividerColor.withOpacity(0.05),
                        border: Border.all(
                          color: hasDiscount ? Colors.red.withOpacity(0.3) : theme.dividerColor.withOpacity(0.1),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            size: 16,
                            color: hasDiscount ? Colors.red : theme.hintColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              hasDiscount ? "Disc: -$currency${cart.discountAmount}" : "Apply Discount",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: hasDiscount ? FontWeight.w600 : FontWeight.normal,
                                color: hasDiscount ? Colors.red : theme.hintColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _showTaxDialog(cart),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: hasTax 
                            ? Colors.blue.withOpacity(0.08) 
                            : theme.dividerColor.withOpacity(0.05),
                        border: Border.all(
                          color: hasTax ? Colors.blue.withOpacity(0.3) : theme.dividerColor.withOpacity(0.1),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_outlined,
                            size: 16,
                            color: hasTax ? Colors.blue : theme.hintColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              hasTax ? "Tax: ${cart.taxRate}%" : "Add Tax/GST",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: hasTax ? FontWeight.w600 : FontWeight.normal,
                                color: hasTax ? Colors.blue : theme.hintColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Grand Total section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Grand Total",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  "$currency${cart.grandTotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Proceed to checkout button
            ElevatedButton(
              onPressed: () => _showCheckoutModal(cart, invoiceProvider, shop, currency, theme),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: theme.primaryColor.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "PROCEED TO PAYMENT",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscountDialog(CartProvider cart) {
    final controller = TextEditingController(text: cart.discountAmount.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Apply Flat Discount"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Discount Amount",
            prefixText: "₹ ",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              cart.setDiscountAmount(amount);
              Navigator.pop(context);
            },
            child: const Text("Apply"),
          )
        ],
      ),
    );
  }

  void _showTaxDialog(CartProvider cart) {
    final controller = TextEditingController(text: cart.taxRate.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Set Tax Rate"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Tax Rate Percentage",
            suffixText: "%",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final rate = double.tryParse(controller.text) ?? 0.0;
              cart.setTaxRate(rate);
              Navigator.pop(context);
            },
            child: const Text("Set"),
          )
        ],
      ),
    );
  }

  void _showCheckoutModal(
    CartProvider cart,
    InvoiceProvider invoiceProvider,
    dynamic shop,
    String currency,
    ThemeData theme,
  ) {
    if (shop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete Business Setup onboarding first!"), backgroundColor: Colors.red),
      );
      return;
    }

    String selectedPayment = 'CASH';
    _customerController.clear();

    final cashReceivedController = TextEditingController();
    double changeAmount = -cart.grandTotal;

    final invoiceNum = _generateInvoiceNumber();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final upiString = cart.generateUpiString(
              upiId: shop.upiId,
              businessName: shop.name,
              invoiceNumber: invoiceNum,
            );

            void updateChange(String val) {
              final rec = double.tryParse(val) ?? 0.0;
              setModalState(() {
                changeAmount = rec - cart.grandTotal;
              });
            }

            return Container(
              decoration: BoxDecoration(
                color: theme.canvasColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 25,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "POS Checkout Payment",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              invoiceNum,
                              style: TextStyle(color: theme.hintColor, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Customer details
                    TextField(
                      controller: _customerController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Customer Mobile Number (Optional)",
                        prefixIcon: const Icon(Icons.phone_iphone_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Payment Method title
                    const Text(
                      "Select Payment Method",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),

                    // Payment Method selector cards
                    Row(
                      children: [
                        _buildPaymentMethodCard(
                          title: "CASH",
                          icon: Icons.payments_outlined,
                          isSelected: selectedPayment == 'CASH',
                          activeColor: const Color(0xFF10B981),
                          onTap: () => setModalState(() => selectedPayment = 'CASH'),
                          theme: theme,
                        ),
                        const SizedBox(width: 10),
                        _buildPaymentMethodCard(
                          title: "UPI QR",
                          icon: Icons.qr_code_scanner_rounded,
                          isSelected: selectedPayment == 'UPI',
                          activeColor: Colors.blueAccent,
                          onTap: () => setModalState(() => selectedPayment = 'UPI'),
                          theme: theme,
                        ),
                        const SizedBox(width: 10),
                        _buildPaymentMethodCard(
                          title: "CARD",
                          icon: Icons.credit_card_rounded,
                          isSelected: selectedPayment == 'CARD',
                          activeColor: Colors.purple,
                          onTap: () => setModalState(() => selectedPayment = 'CARD'),
                          theme: theme,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Dynamic inputs based on selection
                    if (selectedPayment == 'CASH') ...[
                      TextField(
                        controller: cashReceivedController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: updateChange,
                        decoration: InputDecoration(
                          labelText: "Cash Received",
                          prefixText: "₹ ",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 12),

                      // Quick Cash Buttons
                      const Text(
                        "Quick Cash Suggestions",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildQuickCashButton(
                            label: "Exact (${cart.grandTotal.toStringAsFixed(0)})",
                            onTap: () {
                              cashReceivedController.text = cart.grandTotal.toStringAsFixed(2);
                              updateChange(cart.grandTotal.toStringAsFixed(2));
                            },
                            theme: theme,
                          ),
                          _buildQuickCashButton(
                            label: "₹100",
                            onTap: () {
                              cashReceivedController.text = "100.00";
                              updateChange("100.00");
                            },
                            theme: theme,
                          ),
                          _buildQuickCashButton(
                            label: "₹200",
                            onTap: () {
                              cashReceivedController.text = "200.00";
                              updateChange("200.00");
                            },
                            theme: theme,
                          ),
                          _buildQuickCashButton(
                            label: "₹500",
                            onTap: () {
                              cashReceivedController.text = "500.00";
                              updateChange("500.00");
                            },
                            theme: theme,
                          ),
                          _buildQuickCashButton(
                            label: "Clear",
                            onTap: () {
                              cashReceivedController.clear();
                              updateChange("0");
                            },
                            theme: theme,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Balance / Change Due banner
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: changeAmount >= 0 
                              ? Colors.green.withOpacity(0.08) 
                              : Colors.red.withOpacity(0.08),
                          border: Border.all(
                            color: changeAmount >= 0 ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              changeAmount >= 0 ? "Change Due to Customer:" : "Cash Shortage:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: changeAmount >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                            Text(
                              "$currency${changeAmount.abs().toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: changeAmount >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else if (selectedPayment == 'UPI') ...[
                      if (upiString.isNotEmpty) ...[
                        const Text(
                          "Show QR Code to Customer:",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                )
                              ],
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.15), width: 2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: Image.network(
                                    "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(upiString)}",
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(child: CircularProgressIndicator());
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.qr_code_2_rounded, size: 100, color: Colors.blueGrey),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.blueAccent, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Scan to Pay: $currency${cart.grandTotal.toStringAsFixed(2)}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Verify the payment has reached your bank account before completing checkout.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.06),
                            border: Border.all(color: Colors.red.withOpacity(0.2), width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.warning_amber_rounded, size: 40, color: Colors.red),
                              SizedBox(height: 10),
                              Text(
                                "UPI configurations missing in settings",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ] else if (selectedPayment == 'CARD') ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.06),
                          border: Border.all(color: Colors.purple.withOpacity(0.2), width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.contactless_outlined, size: 50, color: Colors.purple),
                            const SizedBox(height: 12),
                            const Text(
                              "Swipe, Dip, or Tap Card",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Please initiate transaction for $currency${cart.grandTotal.toStringAsFixed(2)} on your physical card terminal.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: theme.hintColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Complete checkout button
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedPayment == 'CASH') {
                          final rec = double.tryParse(cashReceivedController.text) ?? 0.0;
                          if (rec < cart.grandTotal) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Insufficient Cash Received!"), backgroundColor: Colors.red),
                            );
                            return;
                          }
                        }

                        final List<InvoiceItem> items = List.from(cart.items);

                        final invoice = Invoice(
                          invoiceNumber: invoiceNum,
                          dateTime: DateTime.now(),
                          totalAmount: cart.totalAmount,
                          taxAmount: cart.calculatedTaxAmount,
                          discountAmount: cart.discountAmount,
                          grandTotal: cart.grandTotal,
                          paymentMethod: selectedPayment,
                          paymentStatus: 'PAID',
                          customerPhone: _customerController.text.trim(),
                          items: items,
                        );

                        final invoiceId = await invoiceProvider.checkout(invoice);

                        if (invoiceId > 0 && context.mounted) {
                          final finalInvoice = await DbHelper().getInvoiceById(invoiceId);
                          
                          if (context.mounted) {
                            cart.clear();
                            Navigator.pop(context);

                            if (finalInvoice != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Checkout Completed!"), backgroundColor: Colors.green),
                              );
                              
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => InvoiceDetailSheet(invoice: finalInvoice),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "COMPLETE TRANSACTION",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentMethodCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : theme.cardColor,
            border: Border.all(
              color: isSelected ? activeColor : theme.dividerColor.withOpacity(0.15),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : theme.hintColor,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? activeColor : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashButton({
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.dividerColor.withOpacity(0.06),
        foregroundColor: theme.textTheme.bodyMedium?.color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
