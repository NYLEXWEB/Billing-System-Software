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

    return Scaffold(
      appBar: AppBar(
        title: const Text("App Configurations", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ==========================================
          // 1. BUSINESS PROFILE SUMMARY
          // ==========================================
          if (shop != null) ...[
            _buildSectionHeader("Shop Details"),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.storefront)),
                title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Phone: ${shop.phone} | GSTIN: ${shop.gstOrTin.isNotEmpty ? shop.gstOrTin : 'N/A'}"),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditShopDialog(context, businessProvider, shop),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ==========================================
          // 2. THEME MODE SETTING
          // ==========================================
          _buildSectionHeader("Appearance Theme"),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Dark Mode Option", style: TextStyle(fontWeight: FontWeight.w500)),
                  DropdownButton<String>(
                    value: shop?.themeMode ?? 'system',
                    underline: const SizedBox(),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 3. PRINTER HARDWARE CONFIGURATION
          // ==========================================
          _buildSectionHeader("Receipt Printer Setup"),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Active printer status
                  Text(
                    printerProvider.activePrinter != null
                        ? "Active Printer: ${printerProvider.activePrinter!.name} (${printerProvider.activePrinter!.paperWidth}mm)"
                        : "No active printer selected",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  
                  // Scanned/saved printers list
                  if (printerProvider.printers.isEmpty)
                    const Text("No configured printers. Setup a Bluetooth or Wi-Fi printer below.", style: TextStyle(color: Colors.grey, fontSize: 13))
                  else
                    Column(
                      children: printerProvider.printers.map((p) {
                        final isActive = printerProvider.activePrinter?.id == p.id;
                        return ListTile(
                          title: Text(p.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text("Type: ${p.type} | Addr: ${p.address}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isActive)
                                TextButton(
                                  onPressed: () => printerProvider.setActivePrinter(p),
                                  child: const Text("Select"),
                                )
                              else
                                const Chip(label: Text("Active", style: TextStyle(fontSize: 10))),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => printerProvider.deletePrinter(p.id!),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showBluetoothScanModal(context, printerProvider),
                          icon: const Icon(Icons.bluetooth),
                          label: const Text("Bluetooth Scan"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showWifiPrinterDialog(context, printerProvider),
                          icon: const Icon(Icons.wifi),
                          label: const Text("Add Wi-Fi IP"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 4. CLOUD BACKUPS (GOOGLE DRIVE)
          // ==========================================
          _buildSectionHeader("Google Drive Backups"),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Google Cloud Status:", style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        authProvider.isAuthenticated ? "Connected" : "Disconnected",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: authProvider.isAuthenticated ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (authProvider.isAuthenticated) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Account: ${authProvider.currentUser?.email}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                  if (backupProvider.lastBackupTime != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Last Backup: ${DateFormat('dd-MMM-yyyy hh:mm a').format(backupProvider.lastBackupTime!)}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                  const Divider(),

                  if (!authProvider.isAuthenticated)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Please sign in to Google in the 'Account & Session' section below to enable cloud backups and restore.",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: backupProvider.isBackupInProgress
                                ? null
                                : () => _promptPasswordForBackup(context, authProvider, backupProvider),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text("Backup Now"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: backupProvider.isRestoreInProgress
                                ? null
                                : () => _promptPasswordForRestore(context, authProvider, backupProvider),
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: const Text("Restore Data"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ==========================================
          // 5. ACCOUNT & SESSION (LOGOUT & RESET)
          // ==========================================
          _buildSectionHeader("Account & Session"),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (authProvider.isAuthenticated) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: authProvider.currentUser?.photoUrl != null
                            ? NetworkImage(authProvider.currentUser!.photoUrl!)
                            : null,
                        child: authProvider.currentUser?.photoUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(authProvider.currentUser?.displayName ?? "Connected User", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(authProvider.currentUser?.email ?? ""),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        tooltip: "Logout & Clear Device Session",
                        onPressed: () {
                          final productProvider = Provider.of<ProductProvider>(context, listen: false);
                          final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                          _showLogoutConfirmation(
                            context,
                            authProvider,
                            businessProvider,
                            productProvider,
                            invoiceProvider,
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Google Drive Session", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Connect to backup your data safely."),
                      trailing: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await authProvider.signIn();
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connected to Google Drive")));
                          }
                        },
                        icon: const Icon(Icons.login),
                        label: const Text("Sign In"),
                      ),
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Reset Shop Details", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Clears current shop profile settings to configure a new one."),
                    trailing: TextButton.icon(
                      onPressed: () => _showResetShopConfirmation(context, businessProvider),
                      icon: const Icon(Icons.refresh, color: Colors.orange),
                      label: const Text("Reset", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent),
      ),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Shop Profile"),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
