import 'package:flutter/material.dart';
import 'legal_document_view_screen.dart';

class LegalMenuScreen extends StatelessWidget {
  const LegalMenuScreen({super.key});

  final List<Map<String, dynamic>> _docs = const [
    {
      'title': 'Privacy Policy',
      'subtitle': 'How we protect and manage your business information.',
      'icon': Icons.privacy_tip_outlined,
      'color': Color(0xFF10B981),
      'asset': 'assets/legal/privacy_policy.txt',
    },
    {
      'title': 'Terms & Conditions',
      'subtitle': 'Terms governing your usage of the EasyToBill application.',
      'icon': Icons.gavel_rounded,
      'color': Color(0xFF3B82F6),
      'asset': 'assets/legal/terms_conditions.txt',
    },
    {
      'title': 'End User License Agreement (EULA)',
      'subtitle': 'Software licensing rights and reverse engineering limits.',
      'icon': Icons.assignment_outlined,
      'color': Color(0xFF6366F1),
      'asset': 'assets/legal/eula.txt',
    },
    {
      'title': 'Refund Policy',
      'subtitle': 'Refund windows, cancellation fees, and exclusions.',
      'icon': Icons.assignment_return_outlined,
      'color': Color(0xFFEF4444),
      'asset': 'assets/legal/refund_policy.txt',
    },
    {
      'title': 'Support Policy',
      'subtitle': 'Scope of technical support and response guidelines.',
      'icon': Icons.contact_support_outlined,
      'color': Color(0xFFF59E0B),
      'asset': 'assets/legal/support_policy.txt',
    },
    {
      'title': 'Data Backup & Restore Policy',
      'subtitle': 'How your Google Drive backups are maintained.',
      'icon': Icons.cloud_sync_outlined,
      'color': Color(0xFF06B6D4),
      'asset': 'assets/legal/backup_restore_policy.txt',
    },
    {
      'title': 'Account Deletion Policy',
      'subtitle': 'Terms of account erasure and data safety.',
      'icon': Icons.no_accounts_outlined,
      'color': Color(0xFF8B5CF6),
      'asset': 'assets/legal/account_deletion_policy.txt',
    },
    {
      'title': 'Disclaimer',
      'subtitle': 'Limitations of software liabilities and statutory rules.',
      'icon': Icons.warning_amber_rounded,
      'color': Color(0xFFEC4899),
      'asset': 'assets/legal/disclaimer.txt',
    },
    {
      'title': 'Printer Warranty Policy',
      'subtitle': 'Warranty terms on manufacturer printer hardware.',
      'icon': Icons.print_outlined,
      'color': Color(0xFF14B8A6),
      'asset': 'assets/legal/printer_warranty_policy.txt',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Legal & Compliance",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        itemCount: _docs.length,
        itemBuilder: (context, index) {
          final doc = _docs[index];
          final Color docColor = doc['color'];
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.05 : 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LegalDocumentViewScreen(
                        title: doc['title'],
                        assetPath: doc['asset'],
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: docColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          doc['icon'],
                          color: docColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc['title'],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doc['subtitle'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
