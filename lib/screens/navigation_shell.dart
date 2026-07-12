import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import 'barcode_scanner_screen.dart';
import 'pos_billing_screen.dart';
import 'dashboard_screen.dart';
import 'product_management_screen.dart';
import 'settings_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const PosBillingScreen(),
    const DashboardScreen(),
    const ProductManagementScreen(),
    const SettingsScreen(),
  ];

  void _handleBottomBarScan(String code) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final products = Provider.of<ProductProvider>(context, listen: false).products;
    
    final product = products.firstWhere(
      (p) => p.barcode == code,
      orElse: () => Product(id: -1, name: '', barcode: '', price: 0.0),
    );
    
    if (product.id != -1) {
      final success = cart.addItem(product);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Added ${product.name} to Billing cart!"),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: "VIEW CART",
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _selectedIndex = 0; // Go to Billing
                });
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Insufficient stock for ${product.name}!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Barcode '$code' not found in catalog."),
          backgroundColor: Colors.amber.shade800,
        ),
      );
    }
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData solidIcon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? solidIcon : outlineIcon,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 72,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.point_of_sale_outlined, Icons.point_of_sale, "Billing"),
              _buildNavItem(1, Icons.dashboard_outlined, Icons.dashboard, "Dashboard"),
              
              // Highlighted Scan button
              GestureDetector(
                onTap: () async {
                  final scannedCode = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                  );
                  if (scannedCode != null && scannedCode.isNotEmpty) {
                    _handleBottomBarScan(scannedCode);
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
                ),
              ),
              
              _buildNavItem(2, Icons.inventory_2_outlined, Icons.inventory_2, "Catalog"),
              _buildNavItem(3, Icons.settings_outlined, Icons.settings, "Settings"),
            ],
          ),
        ),
      ),
    );
  }
}
