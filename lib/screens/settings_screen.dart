import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join, extension;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/business_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/backup_provider.dart';
import '../providers/product_provider.dart';
import '../providers/invoice_provider.dart';
import '../models/printer_settings.dart';
import '../models/business.dart';
import '../data/db_helper.dart';
import '../utils/crypto_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _wifiIpController = TextEditingController();
  final TextEditingController _wifiPortController = TextEditingController(text: '9100');
  
  // Dialog controller for passwords
  final TextEditingController _passwordPromptController = TextEditingController();

  @override
  void dispose() {
    _wifiIpController.dispose();
    _wifiPortController.dispose();
    _passwordPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = Provider.of<BusinessProvider>(context);
    final printerProvider = Provider.of<PrinterProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final backupProvider = Provider.of<BackupProvider>(context);

    final shop = businessProvider.business;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("App Configurations", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Business Profile Card
            if (shop != null) ...[
              _buildShopCard(shop, businessProvider, isDark, theme),
              const SizedBox(height: 24),
            ],

            // 2. Hardware & Device Config
            _buildSectionLabel("Hardware & Device Configuration"),
            _buildGroupCard(
              isDark: isDark,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Sub-card 1: Theme selection
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: _buildSettingsTile(
                          isDark: isDark,
                          icon: Icons.dark_mode_outlined,
                          iconColor: const Color(0xFF3B82F6),
                          title: "Appearance Theme",
                          subtitle: "Switch between light and dark visual modes",
                          trailing: DropdownButton<String>(
                            value: shop?.themeMode ?? 'system',
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'light', child: Text("Light Theme")),
                              DropdownMenuItem(value: 'dark', child: Text("Dark Theme")),
                              DropdownMenuItem(value: 'system', child: Text("System Default")),
                            ],
                            onChanged: (val) async {
                              if (shop != null && val != null) {
                                final updated = shop.copyWith(themeMode: val);
                                await businessProvider.updateBusiness(updated);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Sub-card 2: Printer configurations
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.print_outlined, color: Color(0xFF8B5CF6), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Receipt Printer Setup", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      Text(
                                        printerProvider.activePrinter != null
                                            ? "Active: ${printerProvider.activePrinter!.name} (${printerProvider.activePrinter!.paperWidth}mm)"
                                            : "No active printer selected",
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Saved printers list
                            if (printerProvider.printers.isNotEmpty) ...[
                              ...printerProvider.printers.map((p) {
                                final isActive = printerProvider.activePrinter?.id == p.id;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.print_rounded, size: 18, color: Color(0xFF64748B)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                                            Text("${p.type.toUpperCase()} | ${p.address}", style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                          ],
                                        ),
                                      ),
                                      if (!isActive)
                                        TextButton(
                                          onPressed: () => printerProvider.setActivePrinter(p),
                                          child: const Text("Select", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text("Active", style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                        onPressed: () => printerProvider.deletePrinter(p.id!),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 12),
                            ],
                            // Scan actions (Colored Backgrounds)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showBluetoothScanModal(context, printerProvider),
                                    icon: const Icon(Icons.bluetooth, size: 16),
                                    label: const Text("Bluetooth Scan", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B5CF6), // Purple
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showWifiPrinterDialog(context, printerProvider),
                                    icon: const Icon(Icons.wifi, size: 16),
                                    label: const Text("Add Network IP", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A), // Slate/Black
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              ],
            ),
            const SizedBox(height: 24),

            // 3. Security & Cloud Sync
            _buildSectionLabel("Cloud Backups & Security"),
            _buildGroupCard(
              isDark: isDark,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Sub-card 1: Horizontal grid layout of status boxes (No Dividers)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.cloud_done_outlined, color: Color(0xFF10B981), size: 16),
                                      const SizedBox(width: 6),
                                      const Text("Cloud Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    authProvider.isAuthenticated ? "Connected" : "Disconnected",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: authProvider.isAuthenticated ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.history_rounded, color: Color(0xFFF59E0B), size: 16),
                                      const SizedBox(width: 6),
                                      const Text("Last Backup", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    backupProvider.lastBackupTime != null
                                        ? DateFormat('dd-MMM hh:mm a').format(backupProvider.lastBackupTime!)
                                        : "Never",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Sub-card 2: Backup/Restore Actions
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!authProvider.isAuthenticated)
                              Text(
                                "Please connect your Google Account in the Session section below to enable database backup.",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3),
                                textAlign: TextAlign.center,
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: backupProvider.isBackupInProgress
                                          ? null
                                          : () => _promptPasswordForBackup(context, authProvider, backupProvider),
                                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                                      label: const Text("Backup Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: backupProvider.isRestoreInProgress
                                          ? null
                                          : () => _promptPasswordForRestore(context, authProvider, backupProvider),
                                      icon: const Icon(Icons.cloud_download_outlined, size: 16),
                                      label: const Text("Restore Data", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF59E0B),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              ],
            ),
            const SizedBox(height: 24),

            // 4. Accounts & Sessions
            _buildSectionLabel("Account & Device Sessions"),
            _buildGroupCard(
              isDark: isDark,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Sub-card 1: User Account details (No Dividers)
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: authProvider.isAuthenticated
                            ? ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundImage: authProvider.currentUser?.photoUrl != null
                                      ? NetworkImage(authProvider.currentUser!.photoUrl!)
                                      : null,
                                  child: authProvider.currentUser?.photoUrl == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(authProvider.currentUser?.displayName ?? "Connected User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text(authProvider.currentUser?.email ?? "", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                                    onPressed: () {
                                      final productProvider = Provider.of<ProductProvider>(context, listen: false);
                                      final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                                      _showLogoutConfirmation(context, authProvider, businessProvider, productProvider, invoiceProvider);
                                    },
                                  ),
                                ),
                              )
                            : _buildSettingsTile(
                                isDark: isDark,
                                icon: Icons.login_rounded,
                                iconColor: const Color(0xFF2563EB),
                                title: "Google Cloud Sync",
                                subtitle: "Sign in with Google to enable cloud database sync",
                                trailing: TextButton.icon(
                                  onPressed: () async {
                                    final ok = await authProvider.signIn();
                                    if (ok && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connected to Google Drive")));
                                    }
                                  },
                                  icon: const Icon(Icons.login),
                                  label: const Text("Sign In", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Sub-card 2: Danger Zone (Reset Shop Profile option) with soft red tint
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF7F1D1D).withOpacity(0.15) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF991B1B).withOpacity(0.3) : const Color(0xFFFEE2E2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Reset Shop Profile",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.red.shade300 : const Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Wipe current local configurations & setup again",
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showResetShopConfirmation(context, businessProvider),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text("Reset", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 5. About & Support
            _buildSectionLabel("About & Support"),
            _buildGroupCard(
              isDark: isDark,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("EasyToBill POS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  SizedBox(height: 2),
                                  Text("Version: 1.0.0 (Production)", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  SizedBox(height: 8),
                                  Text(
                                    "EasyToBill is an offline-first POS Billing app designed for small businesses. "
                                    "Your transactions, inventory, and settings are securely stored locally on this device.",
                                    style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.security_outlined, color: Color(0xFF10B981), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("Privacy & Security", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  SizedBox(height: 4),
                                  Text(
                                    "All business operations are fully offline. We do not gather or store any data on external servers. "
                                    "Cloud backups are encrypted using your personal recovery passphrase and saved exclusively to your own Google Drive storage.",
                                    style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildShopCard(Business shop, BusinessProvider provider, bool isDark, ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)], // Obsidian Slate Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative circle
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withOpacity(0.04),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 28),
                      tooltip: "Edit details",
                      onPressed: () => _showEditShopDialog(context, provider, shop),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  shop.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Phone: ${shop.phone}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                if (shop.address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    shop.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "GSTIN: ${shop.gstOrTin.isNotEmpty ? shop.gstOrTin : 'N/A'}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Currency: ${shop.currency}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Color(0xFF64748B),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildGroupCard({required List<Widget> children, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }

  // ==========================================
  // BLUETOOTH SCANNING & SELECTION BOTTOM SHEET
  // ==========================================

  void _showBluetoothScanModal(BuildContext context, PrinterProvider provider) {
    provider.scanBluetoothPrinters();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final devProvider = Provider.of<PrinterProvider>(context);

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Scan Bluetooth Printers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (devProvider.isScanning)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => devProvider.scanBluetoothPrinters(),
                        ),
                    ],
                  ),
                  const Divider(),
                  if (devProvider.discoveredDevices.isEmpty && !devProvider.isScanning)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Text("No paired bluetooth printers found. Pair in settings first.", style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: devProvider.discoveredDevices.length,
                        itemBuilder: (context, index) {
                          final dev = devProvider.discoveredDevices[index];
                          return ListTile(
                            title: Text(dev.name.isNotEmpty ? dev.name : "Unknown Device"),
                            subtitle: Text(dev.macAdress),
                            trailing: const Icon(Icons.bluetooth),
                            onTap: () {
                              _showAddBluetoothDetailsDialog(context, provider, dev.name, dev.macAdress);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddBluetoothDetailsDialog(BuildContext context, PrinterProvider provider, String name, String address) {
    int paperSize = 58;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Configure Printer"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Name: $name"),
              Text("Address: $address"),
              const SizedBox(height: 16),
              const Text("Paper Sizing Width (mm):"),
              Row(
                children: [
                  Radio<int>(
                    value: 58,
                    groupValue: paperSize,
                    onChanged: (val) => setDialogState(() => paperSize = val!),
                  ),
                  const Text("58 mm"),
                  const SizedBox(width: 20),
                  Radio<int>(
                    value: 80,
                    groupValue: paperSize,
                    onChanged: (val) => setDialogState(() => paperSize = val!),
                  ),
                  const Text("80 mm"),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final settings = PrinterSettings(
                  name: name,
                  type: 'bluetooth',
                  address: address,
                  paperWidth: paperSize,
                );
                await provider.addPrinter(settings);
                if (context.mounted) {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // close sheet
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bluetooth printer added.")));
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WI-FI IP PRINTER DIALOG
  // ==========================================

  void _showWifiPrinterDialog(BuildContext context, PrinterProvider provider) {
    int paperSize = 58;
    _wifiIpController.clear();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Network Printer"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _wifiIpController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: "Printer IP Address",
                  hintText: "e.g. 192.168.1.100",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _wifiPortController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Port (Default 9100)",
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Radio<int>(
                    value: 58,
                    groupValue: paperSize,
                    onChanged: (val) => setDialogState(() => paperSize = val!),
                  ),
                  const Text("58 mm"),
                  const SizedBox(width: 20),
                  Radio<int>(
                    value: 80,
                    groupValue: paperSize,
                    onChanged: (val) => setDialogState(() => paperSize = val!),
                  ),
                  const Text("80 mm"),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final ip = _wifiIpController.text.trim();
                final port = _wifiPortController.text.trim();
                if (ip.isEmpty) return;

                final settings = PrinterSettings(
                  name: "Network Printer ($ip)",
                  type: 'network',
                  address: "$ip:$port",
                  paperWidth: paperSize,
                );

                await provider.addPrinter(settings);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wi-Fi network printer added.")));
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CLOUD BACKUPS - SECURITY PROMPTS
  // ==========================================

  void _promptPasswordForBackup(BuildContext context, AuthProvider auth, BackupProvider backup) {
    _passwordPromptController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Encryption PIN"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter your recovery passphrase to encrypt the database backup before uploading:"),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordPromptController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Recovery Password / PIN",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final password = _passwordPromptController.text;
              if (password.isEmpty) return;

              // Validate password against current business recovery password hash
              final shop = Provider.of<BusinessProvider>(context, listen: false).business;
              if (shop != null) {
                final hash = CryptoUtils.hashPassword(password);
                if (hash != shop.recoveryPasswordHash) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Incorrect Recovery Password / PIN!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }

              Navigator.pop(context); // Close dialog

              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing backup to Google Drive...")));
              
              final ok = await backup.backupToGoogleDrive(
                googleSignIn: auth.googleSignIn,
                password: password,
              );

              if (ok) {
                const storage = FlutterSecureStorage();
                await storage.write(key: 'recovery_passphrase', value: password);
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? "Encrypted Backup Saved!" : "Backup failed. Passphrase might be wrong or drive full."),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text("Backup"),
          ),
        ],
      ),
    );
  }

  void _promptPasswordForRestore(BuildContext context, AuthProvider auth, BackupProvider backup) {
    _passwordPromptController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Decryption PIN"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This replaces ALL current local transactions and stock catalogs with the cloud copy.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text("Enter the Recovery Password/PIN to decrypt the file:"),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordPromptController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Recovery Password / PIN",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final password = _passwordPromptController.text;
              if (password.isEmpty) return;
              Navigator.pop(context); // Close dialog
              _triggerRestoreAction(context, auth, backup, password);
            },
            child: const Text("Restore"),
          ),
        ],
      ),
    );
  }

  void _triggerRestoreAction(BuildContext context, AuthProvider auth, BackupProvider backup, String password) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Downloading backup file...")));

    final ok = await backup.restoreFromGoogleDrive(
      googleSignIn: auth.googleSignIn,
      password: password,
      onDatabaseReload: () async {
        final pProvider = Provider.of<ProductProvider>(context, listen: false);
        final iProvider = Provider.of<InvoiceProvider>(context, listen: false);
        final bProvider = Provider.of<BusinessProvider>(context, listen: false);

        await bProvider.loadBusiness();
        await pProvider.loadProducts();
        await pProvider.loadCategories();
        await iProvider.loadInvoices();
      },
    );

    if (ok) {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'recovery_passphrase', value: password);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? "Decrypted Restore Finished!" : "Decryption failed. Incorrect passphrase or missing cloud backup."),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // EDIT SHOP DETAILS DIALOG
  // ==========================================

  void _showEditShopDialog(BuildContext context, BusinessProvider provider, Business shop) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: shop.name);
    final phoneController = TextEditingController(text: shop.phone);
    final emailController = TextEditingController(text: shop.email);
    final addressController = TextEditingController(text: shop.address);
    final gstController = TextEditingController(text: shop.gstOrTin);
    final upiController = TextEditingController(text: shop.upiId);
    final headerController = TextEditingController(text: shop.receiptHeader);
    final footerController = TextEditingController(text: shop.receiptFooter);
    String? currentLogoPath = shop.logoPath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Edit Shop Profile"),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shop Logo Picker Preview
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: Colors.blueAccent.withOpacity(0.1),
                            backgroundImage: currentLogoPath != null && currentLogoPath!.isNotEmpty && File(currentLogoPath!).existsSync()
                                ? FileImage(File(currentLogoPath!))
                                : null,
                            child: currentLogoPath == null || currentLogoPath!.isEmpty || !File(currentLogoPath!).existsSync()
                                ? const Icon(Icons.storefront_rounded, size: 46, color: Colors.blueAccent)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final source = await showModalBottomSheet<ImageSource>(
                                    context: context,
                                    builder: (context) => SafeArea(
                                      child: Wrap(
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.photo_library_rounded),
                                            title: const Text("Pick from Gallery"),
                                            onTap: () => Navigator.pop(context, ImageSource.gallery),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.camera_alt_rounded),
                                            title: const Text("Take Photo with Camera"),
                                            onTap: () => Navigator.pop(context, ImageSource.camera),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (source != null) {
                                    final XFile? pickedFile = await picker.pickImage(
                                      source: source,
                                      maxWidth: 300,
                                      maxHeight: 300,
                                      imageQuality: 80,
                                    );
                                    if (pickedFile != null) {
                                      final docDir = await getApplicationDocumentsDirectory();
                                      final imagesDir = Directory(join(docDir.path, 'images'));
                                      await imagesDir.create(recursive: true);

                                      final ext = extension(pickedFile.path);
                                      final newPath = join(imagesDir.path, 'shop_logo_${DateTime.now().millisecondsSinceEpoch}$ext');
                                      await File(pickedFile.path).copy(newPath);

                                      setState(() {
                                        currentLogoPath = newPath;
                                      });
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                          if (currentLogoPath != null && currentLogoPath!.isNotEmpty)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  icon: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      currentLogoPath = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Shop Name *"),
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Phone Number *"),
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: "Email"),
                    ),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: "Address"),
                    ),
                    TextFormField(
                      controller: gstController,
                      decoration: const InputDecoration(labelText: "GST / TAX No"),
                    ),
                    TextFormField(
                      controller: upiController,
                      decoration: const InputDecoration(labelText: "UPI ID for Payments (Optional)"),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (!v.trim().contains('@')) return "Valid UPI ID required";
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: headerController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Custom Receipt Header",
                        hintText: "e.g. Welcome to Our Shop!",
                      ),
                    ),
                    TextFormField(
                      controller: footerController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Custom Receipt Footer",
                        hintText: "e.g. Thanks for shopping! No return.",
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final updated = shop.copyWith(
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    email: emailController.text.trim(),
                    address: addressController.text.trim(),
                    gstOrTin: gstController.text.trim(),
                    upiId: upiController.text.trim(),
                    receiptHeader: headerController.text.trim(),
                    receiptFooter: footerController.text.trim(),
                    logoPath: currentLogoPath,
                  );

                  final ok = await provider.updateBusiness(updated);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? "Profile updated." : "Failed to update profile.")),
                    );
                  }
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetShopConfirmation(BuildContext context, BusinessProvider businessProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Shop Profile?", style: TextStyle(color: Colors.red)),
        content: const Text(
          "Are you sure you want to delete the current shop details and profile? "
          "This will return the app to the onboarding setup screen. "
          "Your transaction history, products, and printer configuration will remain intact."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await businessProvider.clearBusiness();
              if (context.mounted) {
                // Navigate back to the home page (which will redirect to onboarding)
                Navigator.of(context).popUntil((route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Shop profile cleared.")),
                );
              }
            },
            child: const Text("Reset"),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(
    BuildContext context,
    AuthProvider authProvider,
    BusinessProvider businessProvider,
    ProductProvider productProvider,
    InvoiceProvider invoiceProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Flexible(child: Text("Logout & Clear Session")),
          ],
        ),
        content: const Text(
          "Are you sure you want to log out?\n\n"
          "This will sign you out of your Google Account and clear the local shop data from this device to prevent unauthorized access.\n\n"
          "Please ensure your data is backed up to Google Drive first.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              
              // Clear database and sign out
              await DbHelper().clearDatabase();
              await authProvider.signOut();
              
              // Reload all providers to clean state
              await businessProvider.loadBusiness();
              await productProvider.loadProducts();
              await productProvider.loadCategories();
              await invoiceProvider.loadInvoices();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Logged out successfully. Local data cleared."),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("Log Out"),
          ),
        ],
      ),
    );
  }
}
