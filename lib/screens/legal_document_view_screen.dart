import 'package:flutter/material.dart';

class LegalDocumentViewScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const LegalDocumentViewScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading document",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
            );
          }

          final text = snapshot.data ?? "";
          final paragraphs = text.split('\n');

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: paragraphs.map((para) {
                  final trimmed = para.trim();
                  
                  if (trimmed.isEmpty) {
                    return const SizedBox(height: 8);
                  }

                  if (trimmed == '---') {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      child: Divider(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        thickness: 1,
                      ),
                    );
                  }

                  final isHeading = trimmed.startsWith(RegExp(r'^\d+\.|\b(Effective Date:|Last Updated:|Version:|EASYTOBILL)\b'));
                  if (isHeading) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                      child: Text(
                        trimmed,
                        style: TextStyle(
                          fontSize: trimmed.startsWith('EASYTOBILL') ? 22 : 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          height: 1.3,
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      trimmed,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        height: 1.6,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
