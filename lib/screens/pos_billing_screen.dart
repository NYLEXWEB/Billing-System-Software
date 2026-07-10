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
import 'barcode_scanner_screen.dart';
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
    final rand = Random().nextInt(900) + 100;
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("POS Checkout", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 26),
            tooltip: "Scan Barcode",
            onPressed: () async {
              final String? barcode = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
              );

              if (barcode != null && barcode.isNotEmpty) {
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
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (val) => _onSearchChanged(val, allProducts),
              decoration: InputDecoration(
                hintText: "Search by Name or Barcode...",
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('', allProducts);
                        },
                      )
                    : null,
              ),
            ),
          ),

          // 2. Main Content
          Expanded(
            child: _isSearching
                ? _buildSearchResults(cartProvider, currency)
                : _buildCartView(cartProvider, currency, theme),
          ),

          // 3. Checkout summary card
          if (cartProvider.items.isNotEmpty && !_isSearching)
            _buildCheckoutSection(cartProvider, invoiceProvider, shop, currency, theme),
        ],
      ),
    );
  }

  Widget _buildSearchResults(CartProvider cart, String currency) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: const Color(0xFF94A3B8).withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text(
              "No items match your search",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        final isOutOfStock = product.isTracked && product.stockQuantity == 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                subtitle: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "Price: $currency${product.price.toStringAsFixed(2)}",
                      style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.isTracked ? "Stock: ${product.stockQuantity}" : "Unlimited",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.add_circle_rounded,
                    color: isOutOfStock ? Colors.grey : const Color(0xFF2563EB),
                    size: 28,
                  ),
                  onPressed: isOutOfStock ? null : () => _addToCart(product, cart),
                ),
                onTap: isOutOfStock ? null : () => _addToCart(product, cart),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartView(CartProvider cart, String currency, ThemeData theme) {
    if (cart.items.isEmpty) {
      final productProvider = Provider.of<ProductProvider>(context);
      final popularProducts = productProvider.products.take(6).toList();

      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 72, color: const Color(0xFF94A3B8).withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text(
                "Your checkout cart is empty",
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w500),
              ),
              if (popularProducts.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        "Quick Add Products",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: popularProducts.length,
                  itemBuilder: (context, index) {
                    final p = popularProducts[index];
                    final isOutOfStock = p.isTracked && p.stockQuantity == 0;
                    return InkWell(
                      onTap: isOutOfStock ? null : () => _addToCart(p, cart),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "$currency${p.price.toStringAsFixed(0)}",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isOutOfStock ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p.isTracked ? "${p.stockQuantity} Left" : "Unlimited",
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: cart.items.length,
      itemBuilder: (context, index) {
        final item = cart.items[index];
        final productProvider = Provider.of<ProductProvider>(context, listen: false);
        final product = productProvider.products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(id: item.productId, name: item.productName, barcode: '', price: item.price),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.01),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => cart.removeItem(item.productId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$currency${item.price.toStringAsFixed(2)} each",
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16, color: Color(0xFF475569)),
                              onPressed: () {
                                cart.updateQuantity(item.productId, item.quantity - 1, product);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 28),
                              child: Text(
                                item.quantity.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
                              onPressed: () {
                                final ok = cart.updateQuantity(item.productId, item.quantity + 1, product);
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Insufficient stock quantity!"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "$currency${item.subtotal.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSection(
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
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Subtotal (${cart.items.length} items)",
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  "$currency${cart.totalAmount.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 12),

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
                            ? Colors.red.withOpacity(0.06) 
                            : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: hasDiscount ? Colors.red.withOpacity(0.3) : const Color(0xFFE2E8F0),
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
                            color: hasDiscount ? Colors.red : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              hasDiscount ? "Discount: -$currency${cart.discountAmount}" : "Apply Discount",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: hasDiscount ? FontWeight.bold : FontWeight.normal,
                                color: hasDiscount ? Colors.red : const Color(0xFF64748B),
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
                            ? const Color(0xFFEFF6FF) 
                            : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: hasTax ? const Color(0xFF2563EB).withOpacity(0.3) : const Color(0xFFE2E8F0),
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
                            color: hasTax ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              hasTax ? "Tax Rate: ${cart.taxRate}%" : "Add Tax/GST",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: hasTax ? FontWeight.bold : FontWeight.normal,
                                color: hasTax ? const Color(0xFF2563EB) : const Color(0xFF64748B),
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
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Grand Total",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                ),
                Text(
                  "$currency${cart.grandTotal.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () => _showCheckoutModal(cart, invoiceProvider, shop, currency, theme),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
    final controller = TextEditingController(text: cart.discountAmount > 0 ? cart.discountAmount.toString() : "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Apply Flat Discount", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Discount Amount",
            prefixText: "₹ ",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              cart.setDiscountAmount(amount);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text("Apply"),
          )
        ],
      ),
    );
  }

  void _showTaxDialog(CartProvider cart) {
    final controller = TextEditingController(text: cart.taxRate > 0 ? cart.taxRate.toString() : "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Set Tax Rate", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Tax Rate Percentage",
            suffixText: "%",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              final rate = double.tryParse(controller.text) ?? 0.0;
              cart.setTaxRate(rate);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Payment Settlement",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              invoiceNum,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Customer details
                    TextField(
                      controller: _customerController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Customer Mobile (Optional)",
                        prefixIcon: Icon(Icons.phone_iphone_rounded),
                        hintText: "Enter customer phone",
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      "Select Payment Method",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 10),

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
                          activeColor: const Color(0xFF2563EB),
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

                    // Dynamic settlement details
                    if (selectedPayment == 'CASH') ...[
                      TextField(
                        controller: cashReceivedController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: updateChange,
                        decoration: const InputDecoration(
                          labelText: "Cash Tendered *",
                          prefixText: "₹ ",
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildQuickCashButton(
                            label: "Exact (₹${cart.grandTotal.toStringAsFixed(0)})",
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
                        ],
                      ),
                      const SizedBox(height: 20),

                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: changeAmount >= 0 
                              ? const Color(0xFFECFDF5) 
                              : const Color(0xFFFEF2F2),
                          border: Border.all(
                            color: changeAmount >= 0 ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.3),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              changeAmount >= 0 ? "Change Due:" : "Shortage:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: changeAmount >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                            Text(
                              "$currency${changeAmount.abs().toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: changeAmount >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else if (selectedPayment == 'UPI') ...[
                      if (upiString.isNotEmpty) ...[
                        const Text(
                          "Verify Customer Payment QR",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
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
                                  color: const Color(0xFF2563EB).withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                )
                              ],
                              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.15), width: 1.5),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: const Color(0xFFF8FAFC),
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
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Pay ₹${cart.grandTotal.toStringAsFixed(2)}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Verify transaction confirmation on your bank/merchant app.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2), width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 40, color: Color(0xFFEF4444)),
                              SizedBox(height: 10),
                              Text(
                                "UPI Account details missing in Settings",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
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
                              "Swipe or Tap Card",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Please complete the transaction of ₹${cart.grandTotal.toStringAsFixed(2)} on your card machine.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

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
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
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
                color: isSelected ? activeColor : const Color(0xFF64748B),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? activeColor : const Color(0xFF475569),
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
        backgroundColor: const Color(0xFFF1F5F9),
        foregroundColor: const Color(0xFF475569),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
