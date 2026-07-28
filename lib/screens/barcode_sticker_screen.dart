import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/business.dart';
import '../providers/product_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/business_provider.dart';
import '../services/pdf_service.dart';
import '../widgets/app_toast.dart';

class BarcodeStickerScreen extends StatefulWidget {
  final Product? initialProduct;

  const BarcodeStickerScreen({super.key, this.initialProduct});

  @override
  State<BarcodeStickerScreen> createState() => _BarcodeStickerScreenState();
}

class _BarcodeStickerScreenState extends State<BarcodeStickerScreen> {
  Product? _selectedProduct;
  int _labelLayout = 1; // 1, 2, or 4 barcodes per sticker label
  int _quantity = 1;

  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _customBarcodeController = TextEditingController();
  final TextEditingController _customPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    if (_selectedProduct != null) {
      _customNameController.text = _selectedProduct!.name;
      _customBarcodeController.text = _selectedProduct!.barcode;
      _customPriceController.text = _selectedProduct!.price.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _customBarcodeController.dispose();
    _customPriceController.dispose();
    super.dispose();
  }

  void _onProductSelected(Product? product, ProductProvider provider) {
    setState(() {
      _selectedProduct = product;
      if (product != null) {
        _customNameController.text = product.name;
        _customBarcodeController.text = product.barcode.isEmpty ? provider.generateUniqueBarcode() : product.barcode;
        _customPriceController.text = product.price.toStringAsFixed(2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final productProvider = Provider.of<ProductProvider>(context);
    final printerProvider = Provider.of<PrinterProvider>(context);
    final businessProvider = Provider.of<BusinessProvider>(context);
    final business = businessProvider.business ?? Business(name: "My Store", phone: "", email: "", address: "", gstOrTin: "", upiId: "", currency: "₹");

    final String name = _customNameController.text.trim().isEmpty ? "Sample Product" : _customNameController.text.trim();
    final String barcode = _customBarcodeController.text.trim().isEmpty ? "20268492013" : _customBarcodeController.text.trim();
    final double price = double.tryParse(_customPriceController.text) ?? 0.0;
    final String currency = business.currency.isEmpty || business.currency == '₹' ? 'Rs.' : business.currency;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Barcode Sticker Tool", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Select Product Dropdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB), size: 20),
                      SizedBox(width: 8),
                      Text("Select Product", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Product?>(
                    value: _selectedProduct,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: "Choose a product from catalog...",
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem<Product?>(
                        value: null,
                        child: Text("Custom / Manual Barcode Entry"),
                      ),
                      ...productProvider.products.map(
                        (p) => DropdownMenuItem<Product?>(
                          value: p,
                          child: Text("${p.name} (BC: ${p.barcode.isEmpty ? 'None' : p.barcode})"),
                        ),
                      ),
                    ],
                    onChanged: (p) => _onProductSelected(p, productProvider),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customNameController,
                          decoration: const InputDecoration(
                            labelText: "Product Name",
                            prefixIcon: Icon(Icons.label_outline, size: 18),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _customPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Price",
                            prefixIcon: Icon(Icons.attach_money_rounded, size: 18),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customBarcodeController,
                    decoration: InputDecoration(
                      labelText: "Barcode Value",
                      prefixIcon: const Icon(Icons.qr_code, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6)),
                        tooltip: "Generate Unique Barcode",
                        onPressed: () {
                          final newCode = productProvider.generateUniqueBarcode();
                          setState(() {
                            _customBarcodeController.text = newCode;
                          });
                        },
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Sticker Layout Options (50mm x 25mm)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.aspect_ratio_rounded, color: Color(0xFF8B5CF6), size: 20),
                      SizedBox(width: 8),
                      Text("Sticker Size: 50mm x 25mm", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text("Choose how many barcodes per sticker label:", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildLayoutChip(1, "1 Per Label", "Single"),
                      const SizedBox(width: 8),
                      _buildLayoutChip(2, "2 Per Label", "Dual Split"),
                      const SizedBox(width: 8),
                      _buildLayoutChip(4, "4 Per Label", "2x2 Grid"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Multi-Copy Quantity Stepper
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Sticker Copies", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text("Number of labels to print", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF64748B)),
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "$_quantity",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB)),
                        onPressed: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Live Visual Sticker Preview Widget
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 8),
                      Text("Live Sticker Preview (50x25mm)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: AspectRatio(
                      aspectRatio: 50 / 25, // 2:1 aspect ratio matching 50mm x 25mm
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
                          ],
                        ),
                        child: _buildStickerPreviewContent(name, barcode, price, currency),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 5. Actions (Thermal Direct Print & PDF Export)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (barcode.isEmpty) {
                    AppToast.showError(context, "Please enter or generate a barcode first.");
                    return;
                  }
                  if (printerProvider.activePrinter == null) {
                    AppToast.showInfo(context, "No active printer. Please configure printer in Settings.");
                  }
                  AppToast.showInfo(context, "Printing $_quantity barcode stickers...");
                  final success = await printerProvider.printBarcodeStickers(
                    productName: name,
                    barcode: barcode,
                    price: price,
                    currency: currency,
                    labelLayout: _labelLayout,
                    quantity: _quantity,
                  );
                  if (context.mounted) {
                    if (success) {
                      AppToast.showSuccess(context, "Stickers sent to printer!");
                    } else {
                      AppToast.showError(context, "Thermal print failed. Try printing PDF instead.");
                    }
                  }
                },
                icon: const Icon(Icons.print_rounded),
                label: Text("Print via Bluetooth Thermal Printer ($_quantity)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (barcode.isEmpty) {
                    AppToast.showError(context, "Please enter or generate a barcode first.");
                    return;
                  }
                  await PdfService.generateAndShareBarcodeStickerPdf(
                    productName: name,
                    barcode: barcode,
                    price: price,
                    currency: currency,
                    labelLayout: _labelLayout,
                    quantity: _quantity,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626)),
                label: const Text("Print / Save PDF Stickers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutChip(int layoutVal, String title, String subtitle) {
    final isSelected = _labelLayout == layoutVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _labelLayout = layoutVal),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF2563EB) : Colors.transparent),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickerPreviewContent(String name, String barcode, double price, String currency) {
    if (_labelLayout == 1) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name.toUpperCase(),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Barcode Lines simulation
          Container(
            height: 28,
            width: double.infinity,
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                20,
                (i) => Container(
                  width: i % 3 == 0 ? 3 : 1.5,
                  color: i % 2 == 0 ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(barcode, style: const TextStyle(color: Colors.black, fontSize: 9, fontFamily: 'monospace')),
              Text("$currency${price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ],
      );
    } else if (_labelLayout == 2) {
      return Row(
        children: List.generate(
          2,
          (_) => Expanded(
            child: Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(border: Border.all(color: Colors.black26, width: 0.5)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 8), maxLines: 1),
                  const SizedBox(height: 2),
                  Container(height: 16, width: double.infinity, color: Colors.black),
                  const SizedBox(height: 2),
                  Text("$currency${price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 8)),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return Column(
        children: List.generate(
          2,
          (_) => Expanded(
            child: Row(
              children: List.generate(
                2,
                (_) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black26, width: 0.5)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 7), maxLines: 1),
                        Container(height: 10, width: double.infinity, color: Colors.black),
                        Text("$currency${price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 7)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}
