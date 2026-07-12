import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import '../models/category.dart';
import 'barcode_scanner_screen.dart';
import 'inventory_screen.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      provider.loadProducts();
      provider.loadCategories();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getAvatarColorForLetter(String letter) {
    if (letter.isEmpty) return const Color(0xFF3B82F6);
    final int code = letter.codeUnitAt(0);
    final List<Color> colors = [
      const Color(0xFF2563EB), // Blue
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF14B8A6), // Teal
    ];
    return colors[code % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Catalog Management", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_toggle_off_outlined),
            tooltip: "Stock Control Logs",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InventoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sleek custom pill tab switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0), // Slate 200
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _tabController.animateTo(0);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _tabController.index == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _tabController.index == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 16,
                              color: _tabController.index == 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Products",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _tabController.index == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _tabController.animateTo(1);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _tabController.index == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _tabController.index == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 16,
                              color: _tabController.index == 1 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Categories",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _tabController.index == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(provider, theme),
                _buildCategoriesTab(provider, theme),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showProductFormDialog(context, provider);
          } else {
            _showCategoryFormDialog(context, provider);
          }
        },
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? "New Product" : "New Category"),
      ),
    );
  }

  String _getShortUnit(String unit) {
    switch (unit) {
      case 'Piece': return 'pcs';
      case 'Kilogram': return 'kg';
      case 'Gram': return 'g';
      case 'Litre': return 'ltr';
      case 'Millilitre': return 'ml';
      case 'Pack': return 'pk';
      case 'Box': return 'box';
      case 'Metre': return 'm';
      default: return 'unit';
    }
  }

  // ==========================================
  // PRODUCTS TAB
  // ==========================================

  Widget _buildVerticalCategoryBar(ProductProvider provider, ThemeData theme) {
    return Container(
      width: 110,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // Slate 100
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: provider.categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : provider.categories[index - 1];
          final isSelected = isAll 
              ? provider.selectedCategoryId == null 
              : provider.selectedCategoryId == category?.id;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                provider.setSelectedCategoryId(isAll ? null : category!.id);
              },
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    margin: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    ),
                    child: Text(
                      isAll ? "All Products" : category!.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      left: 0,
                      top: 12,
                      bottom: 12,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsTab(ProductProvider provider, ThemeData theme) {
    return Column(
      children: [
        // Search header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: provider.setSearchQuery,
            decoration: InputDecoration(
              hintText: "Search by name or barcode...",
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB)),
                tooltip: "Scan Barcode to Search",
                onPressed: () async {
                  final scannedCode = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                  );
                  if (scannedCode != null && scannedCode.isNotEmpty) {
                    _searchController.text = scannedCode;
                    provider.setSearchQuery(scannedCode);
                  }
                },
              ),
            ),
          ),
        ),

        // Expanded Row: Left side Categories, Right side Products
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildVerticalCategoryBar(provider, theme),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: const Color(0xFF94A3B8).withOpacity(0.4)),
                                const SizedBox(height: 16),
                                const Text(
                                  "No products found",
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(left: 8, right: 16, top: 4, bottom: 80),
                            itemCount: provider.filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = provider.filteredProducts[index];
                              return _buildProductCard(product, provider, theme);
                            },
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product, ProductProvider provider, ThemeData theme) {
    final hasLowStock = product.isTracked && product.stockQuantity <= product.lowStockThreshold;
    final isOutOfStock = product.isTracked && product.stockQuantity == 0;
    
    Color stockBadgeColor;
    Color stockTextColor;
    String stockLabel;
    
    if (!product.isTracked) {
      stockBadgeColor = const Color(0xFFF1F5F9);
      stockTextColor = const Color(0xFF475569);
      stockLabel = "Unlimited";
    } else if (isOutOfStock) {
      stockBadgeColor = const Color(0xFFFEF2F2);
      stockTextColor = const Color(0xFFEF4444);
      stockLabel = "Out of Stock";
    } else if (hasLowStock) {
      stockBadgeColor = const Color(0xFFFFF7ED);
      stockTextColor = const Color(0xFFF97316);
      stockLabel = "Low Stock: ${product.stockQuantity}";
    } else {
      stockBadgeColor = const Color(0xFFECFDF5);
      stockTextColor = const Color(0xFF10B981);
      stockLabel = "Stock: ${product.stockQuantity}";
    }

    final firstLetter = product.name.isNotEmpty ? product.name[0].toUpperCase() : '?';
    final avatarColor = _getAvatarColorForLetter(firstLetter);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showProductFormDialog(context, provider, product: product),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: avatarColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        firstLetter,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: avatarColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.qr_code, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                product.barcode,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontFamily: "monospace",
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (product.categoryName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  product.categoryName!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: stockBadgeColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                stockLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: stockTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "₹${product.price.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "per ${_getShortUnit(product.unit)}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      if (product.costPrice > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          "Cost: ₹${product.costPrice.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
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

  // ==========================================
  // CATEGORIES TAB
  // ==========================================

  Widget _buildCategoriesTab(ProductProvider provider, ThemeData theme) {
    return provider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : provider.categories.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.category_outlined, size: 64, color: const Color(0xFF94A3B8).withOpacity(0.4)),
                    const SizedBox(height: 16),
                    const Text(
                      "No categories added yet",
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: provider.categories.length,
                itemBuilder: (context, index) {
                  final category = provider.categories[index];
                  return _buildCategoryCard(category, provider, theme);
                },
              );
  }

  Widget _buildCategoryCard(Category category, ProductProvider provider, ThemeData theme) {
    final productsCount = provider.products.where((p) => p.categoryId == category.id).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.folder_open_rounded,
            color: Color(0xFF2563EB),
            size: 22,
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          category.description.isNotEmpty ? category.description : "No description provided",
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$productsCount ${productsCount == 1 ? 'item' : 'items'}",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'edit') {
                  _showCategoryFormDialog(context, provider, category: category);
                } else if (value == 'delete') {
                  _showCategoryDeleteDialog(context, provider, category.id!);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                      SizedBox(width: 8),
                      Text("Edit Category"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text("Delete", style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PRODUCT FORM DIALOG
  // ==========================================

  void _showProductFormDialog(BuildContext context, ProductProvider provider, {Product? product}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product?.name);
    final barcodeController = TextEditingController(text: product?.barcode);
    final priceController = TextEditingController(text: product?.price.toString());
    final costController = TextEditingController(text: product?.costPrice.toString());
    final stockController = TextEditingController(text: product?.stockQuantity.toString());
    final thresholdController = TextEditingController(text: product?.lowStockThreshold.toString());
    
    int? selectedCatId = product?.categoryId;
    bool isTracked = product?.isTracked ?? true;
    String selectedUnit = product?.unit ?? 'Piece';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              title: Row(
                children: [
                  Icon(
                    product == null ? Icons.add_shopping_cart_rounded : Icons.edit_note_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    product == null ? "Add Product" : "Edit Product",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Product Name *",
                          hintText: "Enter product name",
                          prefixIcon: Icon(Icons.shopping_bag_outlined),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: barcodeController,
                        decoration: InputDecoration(
                          labelText: "Barcode / SKU (Optional)",
                          hintText: "Scan or enter barcode",
                          prefixIcon: const Icon(Icons.qr_code),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB)),
                            onPressed: () async {
                              final scannedCode = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                              );
                              if (scannedCode != null && scannedCode.isNotEmpty) {
                                setModalState(() {
                                  barcodeController.text = scannedCode;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              value: selectedCatId,
                              decoration: const InputDecoration(
                                labelText: "Category",
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text("None")),
                                ...provider.categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                              ],
                              onChanged: (val) => setModalState(() => selectedCatId = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              decoration: const InputDecoration(
                                labelText: "Selling Unit *",
                                prefixIcon: Icon(Icons.balance_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Piece', child: Text('Piece (pcs)')),
                                DropdownMenuItem(value: 'Kilogram', child: Text('Kilogram (kg)')),
                                DropdownMenuItem(value: 'Gram', child: Text('Gram (g)')),
                                DropdownMenuItem(value: 'Litre', child: Text('Litre (l)')),
                                DropdownMenuItem(value: 'Millilitre', child: Text('Millilitre (ml)')),
                                DropdownMenuItem(value: 'Pack', child: Text('Pack (pk)')),
                                DropdownMenuItem(value: 'Box', child: Text('Box (bx)')),
                                DropdownMenuItem(value: 'Metre', child: Text('Metre (m)')),
                              ],
                              onChanged: (val) => setModalState(() => selectedUnit = val ?? 'Piece'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Selling Price *",
                                prefixText: "₹ ",
                                prefixIcon: Icon(Icons.sell_outlined),
                              ),
                              validator: (v) => v == null || double.tryParse(v) == null ? "Invalid price" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: costController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: "Cost Price",
                                prefixText: "₹ ",
                                prefixIcon: Icon(Icons.money_off_csred_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: SwitchListTile(
                          title: const Text(
                            "Track Inventory Stock",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: const Text(
                            "Automatically monitor and update stock levels",
                            style: TextStyle(fontSize: 12),
                          ),
                          value: isTracked,
                          activeColor: const Color(0xFF2563EB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          onChanged: (val) => setModalState(() => isTracked = val),
                        ),
                      ),
                      if (isTracked) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Current Stock",
                                  prefixIcon: Icon(Icons.inventory_2_outlined),
                                ),
                                validator: (v) => v == null || int.tryParse(v) == null ? "Invalid count" : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: thresholdController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Low Threshold",
                                  prefixIcon: Icon(Icons.warning_amber_rounded),
                                ),
                                validator: (v) => v == null || int.tryParse(v) == null ? "Invalid threshold" : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
                ),
                if (product != null)
                  TextButton(
                    onPressed: () async {
                      final confirm = await _showProductDeleteConfirmDialog(context);
                      if (confirm == true) {
                        final ok = await provider.deleteProduct(product.id!);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? "Product deleted successfully" : "Delete failed"),
                              backgroundColor: ok ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final name = nameController.text.trim();
                    var barcode = barcodeController.text.trim();
                    if (barcode.isEmpty) {
                      barcode = DateTime.now().microsecondsSinceEpoch.toString();
                    }
                    final price = double.parse(priceController.text);
                    final cost = double.tryParse(costController.text) ?? 0.0;
                    final stock = int.tryParse(stockController.text) ?? 0;
                    final threshold = int.tryParse(thresholdController.text) ?? 5;

                    final updated = Product(
                      id: product?.id,
                      categoryId: selectedCatId,
                      name: name,
                      barcode: barcode,
                      price: price,
                      costPrice: cost,
                      stockQuantity: isTracked ? stock : 0,
                      lowStockThreshold: isTracked ? threshold : 5,
                      isTracked: isTracked,
                      unit: selectedUnit,
                    );

                    bool success;
                    if (product == null) {
                      success = await provider.addProduct(updated);
                    } else {
                      success = await provider.updateProduct(updated);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? "Catalog updated!" : "Failed. Barcode might be duplicate."),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showProductDeleteConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Product?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to permanently delete this product? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CATEGORY FORM DIALOG
  // ==========================================

  void _showCategoryFormDialog(BuildContext context, ProductProvider provider, {Category? category}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category?.name);
    final descController = TextEditingController(text: category?.description);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        title: Row(
          children: [
            Icon(
              category == null ? Icons.create_new_folder_rounded : Icons.folder_shared_rounded,
              color: const Color(0xFF2563EB),
            ),
            const SizedBox(width: 10),
            Text(
              category == null ? "Add Category" : "Edit Category",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Category Name *",
                  hintText: "e.g., Beverages, Snacks",
                  prefixIcon: Icon(Icons.folder_open_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Enter a brief description",
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = nameController.text.trim();
              final desc = descController.text.trim();

              final updated = Category(
                id: category?.id,
                name: name,
                description: desc,
              );

              bool success;
              if (category == null) {
                success = await provider.addCategory(updated);
              } else {
                success = await provider.updateCategory(updated);
              }

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "Category saved successfully!" : "Failed. Name might be duplicate."),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showCategoryDeleteDialog(BuildContext context, ProductProvider provider, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Category?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "Deleting this category will set the category to 'None' for all related products. Product records themselves will NOT be deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await provider.deleteCategory(id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? "Category deleted" : "Delete failed"),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
