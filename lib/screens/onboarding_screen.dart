import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/business.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../providers/business_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/backup_provider.dart';
import '../providers/product_provider.dart';
import '../providers/invoice_provider.dart';
import '../utils/crypto_utils.dart';
import '../data/db_helper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _upiController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  int _currentStep = 0;
  bool _obscurePassword = true;
  bool _isCheckingBackup = false;
  bool _hasCheckedBackup = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.isAuthenticated) {
      if (!_hasCheckedBackup && !_isCheckingBackup) {
        _hasCheckedBackup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkForBackup(authProvider);
        });
      }
    } else {
      _hasCheckedBackup = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _upiController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkForBackup(AuthProvider authProvider) async {
    setState(() {
      _isCheckingBackup = true;
    });
    try {
      final backupProvider = Provider.of<BackupProvider>(context, listen: false);
      final hasBackup = await backupProvider.checkBackupExists(authProvider.googleSignIn);
      if (hasBackup && mounted) {
        _showBackupFoundDialog(context, authProvider, backupProvider);
      }
    } catch (e) {
      debugPrint("Error checking backup on startup: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingBackup = false;
        });
      }
    }
  }

  void _showBackupFoundDialog(BuildContext context, AuthProvider auth, BackupProvider backup) {
    final passwordController = TextEditingController();
    bool obscureText = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.cloud_done_rounded, color: Colors.blueAccent),
              SizedBox(width: 10),
              Flexible(child: Text("Backup Found!", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "We found a database backup associated with your Google Account on Google Drive.\n\n"
                "Would you like to restore it to recover your business profile, products, and invoices?",
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              const Text(
                "Enter Recovery Password / PIN:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: obscureText,
                decoration: InputDecoration(
                  hintText: "Enter your decryption key",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureText = !obscureText),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
              },
              child: const Text("Set Up as New Shop", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter the recovery password")),
                  );
                  return;
                }
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );
                
                final ok = await backup.restoreFromGoogleDrive(
                  googleSignIn: auth.googleSignIn,
                  password: password,
                  onDatabaseReload: () async {
                    final bProvider = Provider.of<BusinessProvider>(context, listen: false);
                    final pProvider = Provider.of<ProductProvider>(context, listen: false);
                    final iProvider = Provider.of<InvoiceProvider>(context, listen: false);
                    
                    await bProvider.loadBusiness();
                    await pProvider.loadProducts();
                    await pProvider.loadCategories();
                    await iProvider.loadInvoices();
                  },
                );
                
                if (context.mounted) {
                  Navigator.pop(context); // Close loading indicator
                }
                
                if (ok) {
                  const storage = FlutterSecureStorage();
                  await storage.write(key: 'recovery_passphrase', value: password);
                  if (context.mounted) {
                    Navigator.pop(dialogContext); // Close backup dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Data restored successfully! Welcome back."),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Failed to decrypt backup. Incorrect password / PIN."),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text("Restore Data"),
            ),
          ],
        ),
      ),
    );
  }

  void _showMandatoryBackupDialog(BuildContext context, AuthProvider auth, BackupProvider backup, String password, BusinessProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.backup_rounded, color: Colors.blueAccent),
              SizedBox(width: 10),
              Flexible(child: Text("Cloud Backup Required", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          content: const Text(
            "To secure your shop details, we require an initial backup to your Google Drive account before continuing.\n\n"
            "This ensures you never lose access to your profile and invoices.",
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: backup.isBackupInProgress
                  ? null
                  : () async {
                      setDialogState(() {});
                      final success = await backup.backupToGoogleDrive(
                        googleSignIn: auth.googleSignIn,
                        password: password,
                      );
                      setDialogState(() {});
                      
                      if (success) {
                        if (context.mounted) {
                          Navigator.pop(dialogContext); // Close dialog
                          await provider.loadBusiness();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Setup completed successfully and backed up to Google Drive!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Backup failed. Please check internet connection and try again."),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: backup.isBackupInProgress
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("Backup Now", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final address = _addressController.text.trim();
    final gst = _gstController.text.trim();
    final upi = _upiController.text.trim();
    final password = _passwordController.text;

    final passwordHash = CryptoUtils.hashPassword(password);

    final business = Business(
      name: name,
      phone: phone,
      email: email,
      address: address,
      gstOrTin: gst,
      upiId: upi,
      recoveryPasswordHash: passwordHash,
      themeMode: 'system',
    );

    final provider = Provider.of<BusinessProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final backup = Provider.of<BackupProvider>(context, listen: false);

    final dbHelper = DbHelper();
    final id = await dbHelper.insertBusiness(business);

    if (id > 0) {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'recovery_passphrase', value: password);
      if (mounted) {
        _showMandatoryBackupDialog(context, auth, backup, password, provider);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save business settings. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGoogleSignInScreen(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/app_logo.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    "Welcome to EasyToBill",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  Text(
                    "Sign in with your Google account to get started and keep your data backed up safely.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 36),

                  if (_isCheckingBackup)
                    const CircularProgressIndicator()
                  else ...[
                    // Custom Google Sign-In Button
                    ElevatedButton(
                      onPressed: () async {
                        final success = await authProvider.signIn();
                        if (success) {
                          if (mounted) {
                            await _checkForBackup(authProvider);
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Google Sign-In failed. Please try again.")),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF3C4043),
                        elevation: 1,
                        shadowColor: Colors.black.withOpacity(0.15),
                        side: const BorderSide(color: Color(0xFFDADCE0), width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const GoogleSignInButtonIcon(size: 20),
                          const SizedBox(width: 12),
                          const Text(
                            "Sign in with Google",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3C4043),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      return _buildGoogleSignInScreen(context, authProvider);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? theme.colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF2563EB).withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/app_logo.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    "Setup your business",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    "Fill in your details to personalize invoices\nand configure local backups.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? theme.colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF0F172A).withOpacity(0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Theme(
                      data: theme.copyWith(
                        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                          fillColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8FAFC),
                        ),
                      ),
                      child: _buildStepper(theme),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Text(
                    "Step ${_currentStep + 1} of 3 • You can edit these details later",
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildStepper(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (_currentStep == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(0),
          const SizedBox(height: 32),
          Text(
            "Basic information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "This appears on every invoice you send.",
            style: TextStyle(
              fontSize: 13,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 24),
          
          _buildInputLabel("Shop / business name *"),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: "e.g. Al Manar Textiles",
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? "Business name is required" : null,
          ),
          const SizedBox(height: 16),
          
          _buildInputLabel("Phone number *"),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: "+91 98765 43210",
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty ? "Phone number is required" : null,
          ),
          const SizedBox(height: 16),
          
          _buildInputLabel("Email address"),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: "you@business.com",
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          
          _buildInputLabel("Business address"),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: "Shop no, street, city",
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                setState(() {
                  _currentStep = 1;
                });
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text("Next step", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(1),
          const SizedBox(height: 32),
          Text(
            "Billing & payments",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Configure tax and UPI details for easy invoicing.",
            style: TextStyle(
              fontSize: 13,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 24),
          
          _buildInputLabel("GSTIN / TAX Number"),
          TextFormField(
            controller: _gstController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: "Optional (e.g. 27AAAAA0000A1Z5)",
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
          ),
          const SizedBox(height: 16),
          
          _buildInputLabel("UPI ID for Payments (Optional)"),
          TextFormField(
            controller: _upiController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: "e.g. merchant@ybl, name@oksbi",
              prefixIcon: Icon(Icons.qr_code_scanner_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null;
              }
              if (!value.contains('@')) {
                return "Invalid UPI ID format (must contain '@')";
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  child: const Text("Back", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final upiText = _upiController.text.trim();
                    if (upiText.isEmpty || upiText.contains('@')) {
                      setState(() => _currentStep = 2);
                    } else {
                      _formKey.currentState!.validate();
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text("Next step", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(2),
          const SizedBox(height: 32),
          Text(
            "Security & backups",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Set a recovery passphrase to encrypt local and cloud backups.",
            style: TextStyle(
              fontSize: 13,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 24),
          
          _buildInputLabel("Recovery Password *"),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: "••••••••",
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return "Recovery password is required";
              if (value.length < 4) return "Password must be at least 4 characters";
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          _buildInputLabel("Confirm Recovery Password *"),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            decoration: const InputDecoration(
              hintText: "••••••••",
              prefixIcon: Icon(Icons.lock_clock_outlined),
            ),
            validator: (value) {
              if (value != _passwordController.text) return "Passwords do not match";
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  child: const Text("Back", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text("Finish setup", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.check, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildStepIndicator(int step) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final unselectedBg = isDark ? theme.colorScheme.surface : Colors.white;
    final unselectedBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    
    final stepLabels = ["Business", "Contact", "Review"];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 3; i++) ...[
              // Step Circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= step ? primaryColor : unselectedBg,
                  border: Border.all(
                    color: i <= step ? primaryColor : unselectedBorder,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    (i + 1).toString(),
                    style: TextStyle(
                      color: i <= step ? Colors.white : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              // Connecting line
              if (i < 2)
                Container(
                  width: 70,
                  height: 2,
                  color: i < step ? primaryColor : unselectedBorder,
                ),
            ]
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 3; i++) ...[
              SizedBox(
                width: 60,
                child: Text(
                  stepLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: i == step ? primaryColor : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 42),
            ]
          ],
        ),
      ],
    );
  }
}

class GoogleSignInButtonIcon extends StatelessWidget {
  final double size;

  const GoogleSignInButtonIcon({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final double strokeWidth = size.width * 0.22;
    final Offset center = Offset(radius, radius);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    final Rect rect = Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2));

    const double startRed = -142.0;
    const double sweepRed = 104.0;

    const double startBlue = -38.0;
    const double sweepBlue = 88.0;

    const double startGreen = 50.0;
    const double sweepGreen = 92.0;

    const double startYellow = 142.0;
    const double sweepYellow = 76.0;

    double toRad(double deg) => deg * 3.141592653589793 / 180.0;

    // Draw Yellow (Left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, toRad(startYellow), toRad(sweepYellow), false, paint);

    // Draw Red (Top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, toRad(startRed), toRad(sweepRed), false, paint);

    // Draw Green (Bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, toRad(startGreen), toRad(sweepGreen), false, paint);

    // Draw Blue (Right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, toRad(startBlue), toRad(sweepBlue), false, paint);

    // Draw the horizontal bar of the 'G'
    final Paint fillPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final double barLeft = radius;
    final double barTop = radius - (strokeWidth / 2);
    final double barRight = size.width - (strokeWidth / 2) + 0.5;
    final double barBottom = radius + (strokeWidth / 2);
    canvas.drawRect(Rect.fromLTRB(barLeft, barTop, barRight, barBottom), fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
