import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:io';
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
import '../widgets/app_toast.dart';

class PosBillingScreen extends StatefulWidget {
  const PosBillingScreen({super.key});

  @override
  State<PosBillingScreen> createState() => _PosBillingScreenState();
}

class _PosBillingScreenState extends State<PosBillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<Product> _searchResults = [];
  bool _isSearching = false;
  bool _viewingCart = false;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

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
    _customerNameController.dispose();
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: _viewingCart
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _viewingCart = false;
                  });
                },
              )
            : null,
        title: Text(_viewingCart ? "Checkout Cart" : "POS Checkout", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                setState(() {
                  _viewingCart = false;
                });
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          if (!_viewingCart) ...[
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
          ],

          // 2. Main Content
          Expanded(
            child: _viewingCart
                ? _buildCartView(cartProvider, currency, theme)
                : (_isSearching
                    ? _buildSearchResults(cartProvider, currency)
                    : _buildCatalogView(cartProvider, currency, theme)),
          ),

          // 3. Bottom Bar (if in catalog view and cart is not empty)
          if (!_viewingCart && cartProvider.items.isNotEmpty)
            _buildCartBottomBar(cartProvider, currency, theme),

          // 4. Checkout summary card (if in cart view and cart is not empty)
          if (_viewingCart && cartProvider.items.isNotEmpty)
            _buildCheckoutSection(cartProvider, invoiceProvider, shop, currency, theme),
        ],
      ),
    );
  }

  Widget _buildSearchResults(CartProvider cart, String currency) {
    final theme = Theme.of(context);
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
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    image: product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync()
                        ? DecorationImage(
                            image: FileImage(File(product.imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: product.imagePath == null || product.imagePath!.isEmpty || !File(product.imagePath!).existsSync()
                      ? const Icon(Icons.shopping_bag_outlined, size: 18, color: Color(0xFF94A3B8))
                      : null,
                ),
                title: Text(
                  product.name,
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                subtitle: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "Price: $currency${product.price.toStringAsFixed(2)}",
                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOutOfStock 
                            ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2)) 
                            : (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.isTracked ? "Stock: ${product.stockQuantity}" : "Unlimited",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock 
                              ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFEF4444)) 
                              : (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981)),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _viewingCart) {
          setState(() {
            _viewingCart = false;
          });
        }
      });
      return const SizedBox.shrink();
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
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF0F172A).withOpacity(0.01),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Thumbnail
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  image: product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync()
                      ? DecorationImage(
                          image: FileImage(File(product.imagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.imagePath == null || product.imagePath!.isEmpty || !File(product.imagePath!).existsSync()
                    ? const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFF94A3B8))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            "$currency${item.price.toStringAsFixed(2)} each",
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                    onPressed: () {
                                      cart.updateQuantity(item.productId, item.quantity - 1, product);
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  ),
                                  InkWell(
                                    onTap: () => _showQuantityEditDialog(context, item, product, cart),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      constraints: const BoxConstraints(minWidth: 24),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.quantity.toString(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
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
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$currency${item.subtotal.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCatalogView(CartProvider cart, String currency, ThemeData theme) {
    final productProvider = Provider.of<ProductProvider>(context);
    final popularProducts = productProvider.products.take(6).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cart.items.isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: const Color(0xFF94A3B8).withOpacity(0.3)),
                  const SizedBox(height: 12),
                  const Text(
                    "Your checkout cart is empty",
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          if (popularProducts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    "Quick Add Products",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        // Image Thumbnail
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            image: p.imagePath != null && p.imagePath!.isNotEmpty && File(p.imagePath!).existsSync()
                                ? DecorationImage(
                                    image: FileImage(File(p.imagePath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: p.imagePath == null || p.imagePath!.isEmpty || !File(p.imagePath!).existsSync()
                              ? const Icon(Icons.shopping_bag_outlined, size: 16, color: Color(0xFF94A3B8))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        // Details Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                p.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "$currency${p.price.toStringAsFixed(0)}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock 
                                          ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2)) 
                                          : (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      p.isTracked ? "${p.stockQuantity}" : "∞",
                                      style: TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold,
                                        color: isOutOfStock 
                                            ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFEF4444)) 
                                            : (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
    );
  }

  Widget _buildCartBottomBar(CartProvider cart, String currency, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${cart.items.length} ${cart.items.length == 1 ? 'Item' : 'Items'}",
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  "Total: $currency${cart.totalAmount.toStringAsFixed(2)}",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _viewingCart = true;
                });
              },
              child: const Row(
                children: [
                  Text("VIEW CART", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuantityEditDialog(BuildContext context, InvoiceItem item, Product product, CartProvider cart) {
    final controller = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Quantity"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Product: ${item.productName}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Quantity",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final newQty = int.tryParse(controller.text) ?? 0;
              if (newQty <= 0) {
                cart.removeItem(item.productId);
              } else {
                final ok = cart.updateQuantity(item.productId, newQty, product);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Insufficient stock quantity!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
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
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF0F172A).withOpacity(0.01),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Thumbnail
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  image: product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync()
                      ? DecorationImage(
                          image: FileImage(File(product.imagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.imagePath == null || product.imagePath!.isEmpty || !File(product.imagePath!).existsSync()
                    ? const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFF94A3B8))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            "$currency${item.price.toStringAsFixed(2)} each",
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                    onPressed: () {
                                      cart.updateQuantity(item.productId, item.quantity - 1, product);
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  ),
                                  InkWell(
                                    onTap: () => _showQuantityEditDialog(context, item, product, cart),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      constraints: const BoxConstraints(minWidth: 24),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.quantity.toString(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
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
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$currency${item.subtotal.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF0F172A).withOpacity(0.06),
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
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  "$currency${cart.totalAmount.toStringAsFixed(2)}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF0F172A)),
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
                            : (isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF1F5F9)),
                        border: Border.all(
                          color: hasDiscount ? Colors.red.withOpacity(0.3) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                            color: hasDiscount ? Colors.red : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              hasDiscount ? "Discount: -$currency${cart.discountAmount}" : "Apply Discount",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: hasDiscount ? FontWeight.bold : FontWeight.normal,
                                color: hasDiscount ? Colors.red : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
                            ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF)) 
                            : (isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF1F5F9)),
                        border: Border.all(
                          color: hasTax ? theme.colorScheme.primary.withOpacity(0.3) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                            color: hasTax ? theme.colorScheme.primary : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              hasTax ? "Tax Rate: ${cart.taxRate}%" : "Add Tax/GST",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: hasTax ? FontWeight.bold : FontWeight.normal,
                                color: hasTax ? theme.colorScheme.primary : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

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
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () => _showCheckoutModal(cart, invoiceProvider, shop, currency, theme),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
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
    _customerNameController.clear();

    final cashReceivedController = TextEditingController();
    final splitAmount1Controller = TextEditingController();
    final splitAmount2Controller = TextEditingController();
    String splitMethod1 = 'CASH';
    String splitMethod2 = 'UPI';

    // Default split values to 50/50
    double halfAmount = cart.grandTotal / 2;
    splitAmount1Controller.text = halfAmount.toStringAsFixed(2);
    splitAmount2Controller.text = (cart.grandTotal - halfAmount).toStringAsFixed(2);

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

            void updateSplitFrom1(String val) {
              final amt1 = double.tryParse(val) ?? 0.0;
              final amt2 = cart.grandTotal - amt1;
              splitAmount2Controller.text = amt2 >= 0 ? amt2.toStringAsFixed(2) : '0.00';
            }

            void updateSplitFrom2(String val) {
              final amt2 = double.tryParse(val) ?? 0.0;
              final amt1 = cart.grandTotal - amt2;
              splitAmount1Controller.text = amt1 >= 0 ? amt1.toStringAsFixed(2) : '0.00';
            }

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                            Text(
                              "Payment Settlement",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            Text(
                              invoiceNum,
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Customer details (Name and Phone, both optional)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customerNameController,
                            keyboardType: TextInputType.name,
                            decoration: const InputDecoration(
                              labelText: "Customer Name (Optional)",
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              hintText: "Enter name",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _customerController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: "Customer Mobile (Optional)",
                              prefixIcon: Icon(Icons.phone_iphone_rounded),
                              hintText: "Enter phone",
                            ),
                          ),
                        ),
                      ],
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
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildPaymentMethodCard(
                          title: "CARD",
                          icon: Icons.credit_card_rounded,
                          isSelected: selectedPayment == 'CARD',
                          activeColor: Colors.purple,
                          onTap: () => setModalState(() => selectedPayment = 'CARD'),
                          theme: theme,
                        ),
                        const SizedBox(width: 10),
                        _buildPaymentMethodCard(
                          title: "SPLIT",
                          icon: Icons.call_split_rounded,
                          isSelected: selectedPayment == 'SPLIT',
                          activeColor: Colors.teal,
                          onTap: () => setModalState(() => selectedPayment = 'SPLIT'),
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
                        onChanged: (val) {
                          setModalState(() {});
                        },
                        decoration: const InputDecoration(
                          labelText: "Cash Tendered (Optional)",
                          prefixText: "₹ ",
                          hintText: "Enter amount to calculate change",
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                              setModalState(() {});
                            },
                            theme: theme,
                          ),
                          _buildQuickCashButton(
                            label: "₹100",
                            onTap: () {
                              cashReceivedController.text = "100.00";
                              setModalState(() {});
                            },
                            theme: theme,
                          ),
                          _buildQuickCashButton(
                            label: "₹200",
                            onTap: () {
                              cashReceivedController.text = "200.00";
                              setModalState(() {});
                            },
                            theme: theme,
                          ),
                          _buildQuickCashButton(
                            label: "₹500",
                            onTap: () {
                              cashReceivedController.text = "500.00";
                              setModalState(() {});
                            },
                            theme: theme,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final input = cashReceivedController.text.trim();
                          if (input.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2), width: 1.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.payments_outlined, color: Color(0xFF10B981)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Collect exact cash: ₹${cart.grandTotal.toStringAsFixed(2)}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final rec = double.tryParse(input) ?? 0.0;
                          final changeAmount = rec - cart.grandTotal;
                          return AnimatedContainer(
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
                                  "₹${changeAmount.abs().toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: changeAmount >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                      const SizedBox(height: 24),
                    ] else if (selectedPayment == 'SPLIT') ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: splitMethod1,
                              decoration: const InputDecoration(labelText: "Method 1"),
                              items: ['CASH', 'UPI', 'CARD'].map((m) {
                                return DropdownMenuItem(value: m, child: Text(m));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    splitMethod1 = val;
                                    if (splitMethod1 == splitMethod2) {
                                      splitMethod2 = ['CASH', 'UPI', 'CARD'].firstWhere((e) => e != splitMethod1);
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: splitMethod2,
                              decoration: const InputDecoration(labelText: "Method 2"),
                              items: ['CASH', 'UPI', 'CARD'].map((m) {
                                return DropdownMenuItem(value: m, child: Text(m));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    splitMethod2 = val;
                                    if (splitMethod2 == splitMethod1) {
                                      splitMethod1 = ['CASH', 'UPI', 'CARD'].firstWhere((e) => e != splitMethod2);
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: splitAmount1Controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: "$splitMethod1 Amount *",
                                prefixText: "₹ ",
                              ),
                              onChanged: updateSplitFrom1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: splitAmount2Controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: "$splitMethod2 Amount *",
                                prefixText: "₹ ",
                              ),
                              onChanged: updateSplitFrom2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildQuickCashButton(
                            label: "Split 50/50",
                            onTap: () {
                              final half = cart.grandTotal / 2;
                              splitAmount1Controller.text = half.toStringAsFixed(2);
                              splitAmount2Controller.text = (cart.grandTotal - half).toStringAsFixed(2);
                            },
                            theme: theme,
                          ),
                          _buildQuickCashButton(
                            label: "All $splitMethod1",
                            onTap: () {
                              splitAmount1Controller.text = cart.grandTotal.toStringAsFixed(2);
                              splitAmount2Controller.text = '0.00';
                            },
                            theme: theme,
                          ),
                          _buildQuickCashButton(
                            label: "All $splitMethod2",
                            onTap: () {
                              splitAmount1Controller.text = '0.00';
                              splitAmount2Controller.text = cart.grandTotal.toStringAsFixed(2);
                            },
                            theme: theme,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ] else if (selectedPayment == 'UPI') ...[
                      if (upiString.isNotEmpty) ...[
                        Text(
                           "Verify Customer Payment QR",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF2563EB).withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                )
                              ],
                              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15), width: 1.5),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8FAFC),
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
                                    Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Pay ₹${cart.grandTotal.toStringAsFixed(2)}",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
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
                        String finalPaymentMethod = selectedPayment;

                        if (selectedPayment == 'CASH') {
                          final recStr = cashReceivedController.text.trim();
                          if (recStr.isNotEmpty) {
                            final rec = double.tryParse(recStr) ?? 0.0;
                            if (rec < cart.grandTotal) {
                              AppToast.showError(context, "Insufficient Cash Tendered!");
                              return;
                            }
                          }
                        } else if (selectedPayment == 'SPLIT') {
                          final amt1 = double.tryParse(splitAmount1Controller.text) ?? 0.0;
                          final amt2 = double.tryParse(splitAmount2Controller.text) ?? 0.0;
                          final sum = amt1 + amt2;
                          if ((sum - cart.grandTotal).abs() > 0.01) {
                            AppToast.showError(context, "Split sum (₹${sum.toStringAsFixed(2)}) must equal Total (₹${cart.grandTotal.toStringAsFixed(2)})!");
                            return;
                          }
                          finalPaymentMethod = 'SPLIT:$splitMethod1=${amt1.toStringAsFixed(2)};$splitMethod2=${amt2.toStringAsFixed(2)}';
                        }

                        final List<InvoiceItem> items = List.from(cart.items);

                        final invoice = Invoice(
                          invoiceNumber: invoiceNum,
                          dateTime: DateTime.now(),
                          totalAmount: cart.totalAmount,
                          taxAmount: cart.calculatedTaxAmount,
                          discountAmount: cart.discountAmount,
                          grandTotal: cart.grandTotal,
                          paymentMethod: finalPaymentMethod,
                          paymentStatus: 'PAID',
                          customerPhone: _customerController.text.trim(),
                          customerName: _customerNameController.text.trim(),
                          items: items,
                        );

                        final invoiceId = await invoiceProvider.checkout(invoice);

                        if (invoiceId > 0 && context.mounted) {
                          // Reload products to update stock quantities in the POS UI
                          Provider.of<ProductProvider>(context, listen: false).loadProducts();
                          
                          final finalInvoice = await DbHelper().getInvoiceById(invoiceId);
                          
                          if (context.mounted) {
                            cart.clear();
                            setState(() {
                              _viewingCart = false;
                            });
                            Navigator.pop(context);

                            if (finalInvoice != null) {
                              AppToast.showSuccess(context, "Checkout Completed!");
                              
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
