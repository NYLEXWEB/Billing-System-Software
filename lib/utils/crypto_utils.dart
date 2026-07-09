import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart' as pc;

class CryptoUtils {
  static String hashPassword(String password) {
    final digest = pc.SHA256Digest();
    final bytes = utf8.encode(password);
    final hashed = digest.process(Uint8List.fromList(bytes));
    return base64.encode(hashed);
  }
}
