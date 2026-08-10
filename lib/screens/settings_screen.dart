import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join, extension;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
import '../services/analytics_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/consent_provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/app_toast.dart';
import 'legal_menu_screen.dart';

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
  void initState() {
    super.initState();
    _initializeSettingsData();
  }

  Future<void> _initializeSettingsData() async {
    // Log settings view event
    await AnalyticsService.logSettingsOpened();
    
    // Set custom Crashlytics keys
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCustomKey('device_model', Platform.localHostname);
      await crashlytics.setCustomKey('android_version', Platform.operatingSystemVersion);
      await crashlytics.setCustomKey('app_version', '1.0.0');
      await crashlytics.setCustomKey('build_number', '1');
    } catch (e) {
      debugPrint("Failed to set Crashlytics keys: $e");
    }

    if (mounted) {
      Provider.of<PrinterProvider>(context, listen: false).checkActivePrinterConnectionStatus();
    }
  }

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
                                            ? (printerProvider.isConnected
                                                ? "Connected: ${printerProvider.activePrinter!.name} (${printerProvider.activePrinter!.paperWidth}mm)"
                                                : "Active (Disconnected): ${printerProvider.activePrinter!.name} (${printerProvider.activePrinter!.paperWidth}mm)")
                                            : "No active printer selected",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: printerProvider.activePrinter != null
                                              ? (printerProvider.isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                                              : const Color(0xFF64748B),
                                          fontWeight: printerProvider.activePrinter != null ? FontWeight.w600 : FontWeight.normal,
                                        ),
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
                                            color: printerProvider.isConnected
                                                ? const Color(0xFFD1FAE5)
                                                : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            printerProvider.isConnected ? "Connected" : "Disconnected",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: printerProvider.isConnected
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFD97706),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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

                            // Test Active Printer Option
                            if (printerProvider.activePrinter != null) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
                                    final business = businessProvider.business ?? Business(name: "Sample Store", phone: "", email: "", address: "", gstOrTin: "", upiId: "", currency: "₹");
                                    AppToast.showInfo(context, "Testing printer connection...");
                                    final success = await printerProvider.testPrintActivePrinter(business);
                                    if (context.mounted) {
                                      if (success) {
                                        AppToast.showSuccess(context, "Test receipt printed successfully!");
                                      } else {
                                        AppToast.showError(context, "Test print failed. Ensure Bluetooth is ON and paired.");
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.print_outlined, size: 16),
                                  label: const Text("Test Active Printer", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF10B981),
                                    side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
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
                      const SizedBox(height: 12),

                      // Sub-card 2.5: Account Deletion (Danger Zone style)
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
                                    "Delete My Account",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.red.shade300 : const Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Permanently delete your account and wipe all local databases",
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _handleAccountDeletion(context, businessProvider, authProvider),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.headset_mic_rounded, color: Color(0xFF2563EB), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("Help & Customer Support", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  SizedBox(height: 4),
                                  Text(
                                    "Phone / WhatsApp: +91 8921442748\nEmail: buildwithnylex@gmail.com",
                                    style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _showContactSupportModal(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text("Contact", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

            // 6. Legal & Compliance
            _buildSectionLabel("Legal & Compliance"),
            _buildGroupCard(
              isDark: isDark,
              children: [
                _buildSettingsTile(
                  isDark: isDark,
                  icon: Icons.gavel_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  title: "Legal Agreements",
                  subtitle: "Terms of Service, Privacy Policy, EULA, and more",
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LegalMenuScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 80), // Extra bottom padding for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showContactSupportModal(context),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.headset_mic_rounded, size: 20),
        label: const Text(
          "Help & Support",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final devProvider = Provider.of<PrinterProvider>(context);

            return Container(
              height: MediaQuery.of(context).size.height * 0.55,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Select Bluetooth Printer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      if (devProvider.isScanning)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                          tooltip: "Refresh Devices",
                          onPressed: () => devProvider.scanBluetoothPrinters(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text("Showing Bluetooth devices paired with this phone", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const Divider(height: 24),
                  if (devProvider.isScanning)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Scanning paired Bluetooth devices...", style: TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    )
                  else if (devProvider.discoveredDevices.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bluetooth_disabled_rounded, size: 54, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            const Text("No Paired Devices Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 6),
                            const Text(
                              "Please pair your Bluetooth printer in Phone Settings first, then tap Scan Again.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => devProvider.scanBluetoothPrinters(),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text("Scan Again"),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: devProvider.discoveredDevices.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final dev = devProvider.discoveredDevices[index];
                          final devName = dev.name.isNotEmpty ? dev.name : "Bluetooth Printer / Device";
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.print_rounded, color: Color(0xFF2563EB)),
                            ),
                            title: Text(devName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Text("MAC: ${dev.macAdress}", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB)),
                            onTap: () {
                              Navigator.pop(context);
                              _showAddBluetoothDetailsDialog(context, provider, devName, dev.macAdress);
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showManualMacAddressDialog(context, provider);
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: const Text("Enter MAC Address Manually"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showManualMacAddressDialog(BuildContext context, PrinterProvider provider) {
    final nameController = TextEditingController(text: "Thermal Printer");
    final macController = TextEditingController();
    int paperSize = 58;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Printer via MAC Address"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Printer Name",
                  hintText: "e.g. POS-58 Thermal",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: macController,
                decoration: const InputDecoration(
                  labelText: "Bluetooth MAC Address",
                  hintText: "e.g. 00:11:22:33:44:55",
                ),
              ),
              const SizedBox(height: 16),
              const Text("Paper Width:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Row(
                children: [
                  Radio<int>(
                    value: 58,
                    groupValue: paperSize,
                    onChanged: (val) => setDialogState(() => paperSize = val!),
                  ),
                  const Text("58mm"),
                  const SizedBox(width: 16),
                  Radio<int>(
                    value: 80,
                    groupValue: paperSize,
                    onChanged: (val) => setDialogState(() => paperSize = val!),
                  ),
                  const Text("80mm"),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final mac = macController.text.trim();
                final name = nameController.text.trim();
                if (mac.isEmpty) return;
                Navigator.pop(context);
                final newPrinter = PrinterSettings(
                  name: name.isEmpty ? "Thermal Printer" : name,
                  type: 'bluetooth',
                  address: mac,
                  paperWidth: paperSize,
                );
                await provider.addPrinter(newPrinter);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Added Printer: $name ($mac)")),
                  );
                }
              },
              child: const Text("Save Printer"),
            ),
          ],
        ),
      ),
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
                final storage = const FlutterSecureStorage();
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
      final storage = const FlutterSecureStorage();
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: const [
                Icon(Icons.storefront_rounded, color: Colors.blueAccent),
                SizedBox(width: 12),
                Text("Edit Shop Profile", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: 24),
                    
                    _buildDialogField(
                      controller: nameController,
                      labelText: "Shop Name *",
                      hintText: "e.g. Al Manar Textiles",
                      icon: Icons.storefront_outlined,
                      isDark: isDark,
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDialogField(
                      controller: phoneController,
                      labelText: "Phone Number *",
                      hintText: "+91 98765 43210",
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      isDark: isDark,
                      validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDialogField(
                      controller: emailController,
                      labelText: "Email Address",
                      hintText: "you@business.com",
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDialogField(
                      controller: addressController,
                      labelText: "Business Address",
                      hintText: "Shop no, street, city",
                      icon: Icons.location_on_outlined,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDialogField(
                      controller: gstController,
                      labelText: "GST / TAX No",
                      hintText: "Optional",
                      icon: Icons.receipt_long_outlined,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDialogField(
                      controller: upiController,
                      labelText: "UPI ID for Payments",
                      hintText: "e.g. name@oksbi",
                      icon: Icons.qr_code_scanner_outlined,
                      isDark: isDark,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (!v.trim().contains('@')) return "Valid UPI ID required";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDialogField(
                      controller: headerController,
                      labelText: "Custom Receipt Header",
                      hintText: "e.g. Welcome to Our Shop!",
                      icon: Icons.vertical_align_top_rounded,
                      maxLines: 2,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDialogField(
                      controller: footerController,
                      labelText: "Custom Receipt Footer",
                      hintText: "e.g. Thanks for shopping! No return.",
                      icon: Icons.vertical_align_bottom_rounded,
                      maxLines: 2,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
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

  Widget _buildDialogField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF2563EB),
            width: 1.5,
          ),
        ),
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

  void _handleAccountDeletion(BuildContext context, BusinessProvider businessProvider, AuthProvider authProvider) {
    final TextEditingController passwordController = TextEditingController();
    final shop = businessProvider.business;
    
    if (shop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No active shop/account profile found.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verify Security Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("To proceed with account deletion, please enter your EasyToBill Security Password:"),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Security Password",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final password = passwordController.text;
              if (password.isEmpty) return;

              final hash = CryptoUtils.hashPassword(password);
              if (hash != shop.recoveryPasswordHash) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text("Incorrect Security Password!"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext); // Close verification dialog
              _showFinalDeletionConfirmation(context, businessProvider, authProvider);
            },
            child: const Text("Verify"),
          ),
        ],
      ),
    );
  }

  void _showFinalDeletionConfirmation(BuildContext context, BusinessProvider businessProvider, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Flexible(child: Text("Permanently Delete Account?")),
          ],
        ),
        content: const Text(
          "WARNING: Account deletion is permanent and cannot be undone!\n\n"
          "This will:\n"
          "1. Permanently delete all local business data, products, inventory, transactions, and settings from this device.\n"
          "2. Sign you out of your Google Account connection.\n"
          "3. Reset the application to its first-launch state.\n\n"
          "Your Google Drive backup files will not be deleted, but you will lose access to them from this device. Please refer to the Account Deletion Policy for details.",
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

              // Clear local database
              await DbHelper().clearDatabase();
              
              // Clear consent status so next login/onboarding re-triggers consent
              final consentProvider = Provider.of<ConsentProvider>(context, listen: false);
              await consentProvider.clearConsent();

              // Sign out of auth provider
              await authProvider.signOut();

              // Reload all providers to clean state
              final productProvider = Provider.of<ProductProvider>(context, listen: false);
              final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
              
              await businessProvider.loadBusiness();
              await productProvider.loadProducts();
              await productProvider.loadCategories();
              await invoiceProvider.loadInvoices();

              if (context.mounted) {
                // Navigate back to the home page (which will redirect to user agreement/onboarding)
                Navigator.of(context).popUntil((route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Account successfully deleted and local data cleared."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Delete Account"),
          ),
        ],
      ),
    );
  }

  void _showContactSupportModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final queryController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Top Drag handle & Header bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.headset_mic_rounded, color: Color(0xFF2563EB), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Customer Support & FAQs",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const Text(
                                  "EasyToBill Support Desk",
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Direct Contact Cards
                          Text(
                            "DIRECT CONTACT CHANNELS",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Phone / WhatsApp Row
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981), size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Phone & WhatsApp",
                                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "+91 8921442748",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        Clipboard.setData(const ClipboardData(text: "+918921442748"));
                                        AppToast.showSuccess(context, "Phone number copied: +91 8921442748");
                                      },
                                      icon: const Icon(Icons.copy_rounded, size: 14),
                                      label: const Text("Copy", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF10B981),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                                // Support Email Row
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.email_rounded, color: Color(0xFF2563EB), size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Support Email",
                                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "buildwithnylex@gmail.com",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        Clipboard.setData(const ClipboardData(text: "buildwithnylex@gmail.com"));
                                        AppToast.showSuccess(context, "Email copied: buildwithnylex@gmail.com");
                                      },
                                      icon: const Icon(Icons.copy_rounded, size: 14),
                                      label: const Text("Copy", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF2563EB),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 2. Interactive FAQ Assistant
                          Text(
                            "FREQUENTLY ASKED QUESTIONS",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildFaqTile(
                            isDark: isDark,
                            question: "How do I connect my Bluetooth thermal printer?",
                            answer: "1. Turn on your Bluetooth printer.\n2. Pair the printer in your phone's Bluetooth settings.\n3. In EasyToBill Settings, go to 'Hardware & Device Configuration' -> tap 'Bluetooth Scan'.\n4. Select your printer and tap 'Active'.",
                          ),
                          _buildFaqTile(
                            isDark: isDark,
                            question: "How do I back up my billing data to Google Drive?",
                            answer: "1. In EasyToBill Settings, scroll down to 'Account & Device Sessions'.\n2. Tap 'Sign in with Google' and authorize your account.\n3. Under 'Database Cloud Storage', tap 'Backup Now' and enter your passphrase.",
                          ),
                          _buildFaqTile(
                            isDark: isDark,
                            question: "How do I add custom one-off items during checkout?",
                            answer: "1. Go to POS Checkout.\n2. Tap 'VIEW CART'.\n3. Scroll down to the bottom of the items list and tap 'Add Custom Product'.\n4. Enter the item name, price, and quantity.",
                          ),
                          _buildFaqTile(
                            isDark: isDark,
                            question: "How do I change my shop name, phone, or receipt logo?",
                            answer: "In Settings, tap the Edit button on your Business Profile Card at the top. You can update shop name, address, phone number, currency symbol, and shop logo.",
                          ),
                          _buildFaqTile(
                            isDark: isDark,
                            question: "How do I apply discounts or Tax/GST to a bill?",
                            answer: "In POS Checkout, tap 'VIEW CART'. Use the 'Apply Discount' or 'Add Tax/GST' buttons at the bottom before proceeding to payment.",
                          ),
                          _buildFaqTile(
                            isDark: isDark,
                            question: "Is my business data safe offline?",
                            answer: "Yes! EasyToBill is 100% offline-first. All your sales, products, and invoices are stored locally on your device. Cloud backup is optional and encrypted.",
                          ),
                          const SizedBox(height: 24),

                          // 3. Ask Support a Custom Question Box
                          Text(
                            "ASK CUSTOM QUESTION / REPORT ISSUE",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: queryController,
                                  maxLines: 3,
                                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: "Describe your question or issue...",
                                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final query = queryController.text.trim();
                                    final fullMessage = "EasyToBill Support Query:\n\n${query.isNotEmpty ? query : "Need technical assistance with EasyToBill app."}\n\nApp Version: 1.0.0\nDevice: ${Platform.operatingSystem}\nContact Support: +91 8921442748 | buildwithnylex@gmail.com";
                                    Clipboard.setData(ClipboardData(text: fullMessage));
                                    Share.share(fullMessage);
                                    AppToast.showSuccess(context, "Support message formatted & ready to share!");
                                  },
                                  icon: const Icon(Icons.send_rounded, size: 16),
                                  label: const Text("Send Query to Support", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
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

  Widget _buildFaqTile({
    required bool isDark,
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFF2563EB),
          collapsedIconColor: const Color(0xFF64748B),
          title: Text(
            question,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
