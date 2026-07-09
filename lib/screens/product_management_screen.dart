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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Catalog Management", style: TextStyle(fontWeight: FontWeight.bold)),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Products", icon: Icon(Icons.shopping_bag_outlined)),
            Tab(text: "Categories", icon: Icon(Icons.category_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(provider, theme),
          _buildCategoriesTab(provider, theme),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showProductFormDialog(context, provider);
          } else {
            _showCategoryFormDialog(context, provider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ==========================================
  // PRODUCTS TAB
  // ==========================================

  Widget _buildProductsTab(ProductProvider provider, ThemeData theme) {
    return Column(
      children: [
        // Search & Filter header
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: provider.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: "Search products...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Category filter dropdown
              DropdownButton<int?>(
                value: provider.selectedCategoryId,
                hint: const Text("All"),
                underline: const SizedBox(),
                icon: const Icon(Icons.filter_alt_outlined),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text("All Categories")),
                  ...provider.categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                ],
                onChanged: provider.setSelectedCategoryId,
              ),
            ],
          ),
        ),

        // Products List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: theme.hintColor.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text("No products found in catalog", style: TextStyle(color: theme.hintColor)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: provider.filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = provider.filteredProducts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("SKU/Barcode: ${product.barcode}"),
                                if (product.categoryName != null) Text("Category: ${product.categoryName}"),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("Price: ₹${product.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  product.isTracked ? "Stock: ${product.stockQuantity}" : "Unlimited Stock",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: product.isTracked && product.stockQuantity <= product.lowStockThreshold
                                        ? Colors.red
                                        : theme.hintColor,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showProductFormDialog(context, provider, product: product),
                          ),
                        );
                      },
                    ),
        ),
      ],
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
                    Icon(Icons.category_outlined, size: 64, color: theme.hintColor.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text("No categories added yet", style: TextStyle(color: theme.hintColor)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: provider.categories.length,
                itemBuilder: (context, index) {
                  final category = provider.categories[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(category.description.isNotEmpty ? category.description : "No description"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showCategoryFormDialog(context, provider, category: category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _showCategoryDeleteDialog(context, provider, category.id!),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(product == null ? "Add Product" : "Edit Product"),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: "Product Name *"),
                        validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: barcodeController,
                              decoration: const InputDecoration(labelText: "Barcode / SKU *"),
                              validator: (v) => v == null || v.trim().isEmpty ? "Barcode is required" : null,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
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
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int?>(
                        value: selectedCatId,
                        decoration: const InputDecoration(labelText: "Category"),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text("None")),
                          ...provider.categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (val) => setModalState(() => selectedCatId = val),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: "Selling Price *"),
                              validator: (v) => v == null || double.tryParse(v) == null ? "Invalid price" : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: costController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: "Cost Price"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text("Track Inventory Stock"),
                        value: isTracked,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setModalState(() => isTracked = val),
                      ),
                      if (isTracked) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: "Current Stock"),
                                validator: (v) => v == null || int.tryParse(v) == null ? "Invalid count" : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: thresholdController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: "Low Threshold"),
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
                  child: const Text("Cancel"),
                ),
                if (product != null)
                  TextButton(
                    onPressed: () async {
                      final ok = await provider.deleteProduct(product.id!);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? "Product deleted" : "Delete failed")),
                        );
                      }
                    },
                    child: const Text("Delete", style: TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final name = nameController.text.trim();
                    final barcode = barcodeController.text.trim();
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
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
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
      builder: (context) => AlertDialog(
        title: Text(category == null ? "Add Category" : "Edit Category"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Category Name *"),
                validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
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
                    content: Text(success ? "Category saved!" : "Failed. Name might be duplicate."),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
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
        title: const Text("Delete Category?"),
        content: const Text(
          "Deleting this category will set the category to 'None' for all related products. Product records themselves will NOT be deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await provider.deleteCategory(id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? "Category deleted" : "Delete failed")),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
