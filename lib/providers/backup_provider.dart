import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import 'auth_provider.dart';
import 'business_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class BackupProvider extends ChangeNotifier {
  bool _isBackupInProgress = false;
  bool _isRestoreInProgress = false;
  DateTime? _lastBackupTime;

  bool get isBackupInProgress => _isBackupInProgress;
  bool get isRestoreInProgress => _isRestoreInProgress;
  DateTime? get lastBackupTime => _lastBackupTime;

  // ==========================================
  // PBKDF2 & AES ENCRYPTION HELPERS
  // ==========================================

  Uint8List _deriveKey(String password, String salt) {
    final saltBytes = Uint8List.fromList(utf8.encode(salt));
    final pkcs = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64));
    pkcs.init(pc.Pbkdf2Parameters(saltBytes, 1000, 32)); // 1000 iterations, 256-bit key
    return pkcs.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List _encryptData(Uint8List data, String password) {
    // Derive key using recovery password. Standard salt 'POS_BACKUP_SALT' used.
    final keyBytes = _deriveKey(password, 'POS_BACKUP_SALT_2026');
    final key = enc.Key(keyBytes);
    
    // Generate random 12-byte IV for AES-GCM
    final iv = enc.IV.fromSecureRandom(12);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    
    // Prepend IV (12 bytes) to ciphertext
    final Uint8List result = Uint8List(12 + encrypted.bytes.length);
    result.setRange(0, 12, iv.bytes);
    result.setRange(12, result.length, encrypted.bytes);
    
    return result;
  }

  Uint8List _decryptData(Uint8List encryptedData, String password) {
    if (encryptedData.length < 12) {
      throw Exception("Ciphertext too short. Invalid backup file.");
    }
    // Extract IV (first 12 bytes)
    final ivBytes = encryptedData.sublist(0, 12);
    final ciphertextBytes = encryptedData.sublist(12);
    
    final keyBytes = _deriveKey(password, 'POS_BACKUP_SALT_2026');
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(ciphertextBytes), iv: iv);
    
    return Uint8List.fromList(decrypted);
  }

  // ==========================================
  // GOOGLE DRIVE BACKUP & RESTORE
  // ==========================================

  Future<bool> backupToGoogleDrive({
    required GoogleSignIn googleSignIn,
    required String password,
  }) async {
    _isBackupInProgress = true;
    notifyListeners();
    try {
      // 1. Get database path and read file
      final dbPath = join(await getDatabasesPath(), 'shop_billing.db');
      if (!await databaseFactory.databaseExists(dbPath)) {
        throw Exception("Local database does not exist");
      }
      final dbBytes = await databaseFactory.readDatabaseBytes(dbPath);

      // Create ZIP Archive
      final archive = Archive();
      archive.addFile(ArchiveFile('shop_billing.db', dbBytes.length, dbBytes));

      // Retrieve local images and add to ZIP
      final docDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(join(docDir.path, 'images'));
      if (await imagesDir.exists()) {
        final filesList = imagesDir.listSync(recursive: true);
        for (final entity in filesList) {
          if (entity is File) {
            final relativePath = relative(entity.path, from: docDir.path);
            final fileBytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile(relativePath, fileBytes.length, fileBytes));
          }
        }
      }

      // Encode archive to zip
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        throw Exception("Failed to package backup files");
      }

      // 2. Encrypt zip bytes
      final encryptedBytes = _encryptData(Uint8List.fromList(zipBytes), password);

      // 3. Connect to Google Drive using authenticated client extension
      final authClient = await googleSignIn.authenticatedClient();
      if (authClient == null) {
        throw Exception("Failed to create authenticated Google client");
      }
      final driveApi = drive.DriveApi(authClient);

      // 4. Check if file already exists in AppData folder
      final fileList = await driveApi.files.list(
        q: "name = 'shop_billing_backup.enc'",
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      final media = drive.Media(Stream.value(encryptedBytes), encryptedBytes.length);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Update existing backup file
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(
          drive.File(),
          fileId,
          uploadMedia: media,
        );
      } else {
        // Create new backup file
        final driveFile = drive.File()
          ..name = 'shop_billing_backup.enc'
          ..parents = ['appDataFolder'];
        await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
      }

      _lastBackupTime = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Backup to Google Drive failed: $e");
      return false;
    } finally {
      _isBackupInProgress = false;
      notifyListeners();
    }
  }

  Future<bool> checkBackupExists(GoogleSignIn googleSignIn) async {
    try {
      final authClient = await googleSignIn.authenticatedClient();
      if (authClient == null) return false;
      final driveApi = drive.DriveApi(authClient);
      final fileList = await driveApi.files.list(
        q: "name = 'shop_billing_backup.enc'",
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );
      return fileList.files != null && fileList.files!.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking backup existence: $e");
      return false;
    }
  }

  Future<bool> restoreFromGoogleDrive({
    required GoogleSignIn googleSignIn,
    required String password,
    required Function() onDatabaseReload,
  }) async {
    _isRestoreInProgress = true;
    notifyListeners();
    try {
      // 1. Connect to Google Drive
      final authClient = await googleSignIn.authenticatedClient();
      if (authClient == null) {
        throw Exception("Failed to create authenticated Google client");
      }
      final driveApi = drive.DriveApi(authClient);

      // 2. Locate backup file
      final fileList = await driveApi.files.list(
        q: "name = 'shop_billing_backup.enc'",
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        throw Exception("No backup file found on Google Drive.");
      }

      final fileId = fileList.files!.first.id!;

      // 3. Download backup bytes
      final drive.Media response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> bytesList = [];
      await response.stream.forEach((chunk) => bytesList.addAll(chunk));
      final encryptedBytes = Uint8List.fromList(bytesList);

      // 4. Decrypt backup bytes
      final decryptedBytes = _decryptData(encryptedBytes, password);

      // 5. Safe Database Hot-Swap & File Extraction
      // Close database connection first
      await DbHelper().closeDatabase();

      // Decode ZIP archive
      final archiveArchive = ZipDecoder().decodeBytes(decryptedBytes);
      final docDir = await getApplicationDocumentsDirectory();

      for (final file in archiveArchive) {
        final filename = file.name;
        if (file.isFile) {
          final fileData = file.content as List<int>;
          if (filename == 'shop_billing.db') {
            final dbPath = join(await getDatabasesPath(), 'shop_billing.db');
            final outFile = File(dbPath);
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(fileData, flush: true);
          } else if (filename.startsWith('images/')) {
            final outFile = File(join(docDir.path, filename));
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(fileData, flush: true);
          }
        }
      }

      // Callback to clear memory state and re-open SQLite connection
      onDatabaseReload();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Restore from Google Drive failed: $e");
      return false;
    } finally {
      _isRestoreInProgress = false;
      notifyListeners();
    }
  }

  // ==========================================
  // AUTOMATIC DAILY BACKUPS
  // ==========================================

  Future<void> checkAndPerformAutoBackup({
    required AuthProvider authProvider,
    required BusinessProvider businessProvider,
  }) async {
    // 1. Check if user is authenticated with Google
    if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
      debugPrint("Auto-backup skipped: User not logged in to Google.");
      return;
    }

    // 2. Check if we already did an automatic backup today
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    const storage = FlutterSecureStorage();
    
    try {
      final lastAutoBackupDate = await storage.read(key: 'last_auto_backup_date');
      if (lastAutoBackupDate == todayStr) {
        debugPrint("Auto-backup skipped: Already backed up today.");
        return;
      }

      // 3. Get the encryption passphrase
      final password = await storage.read(key: 'recovery_passphrase');
      if (password == null || password.isEmpty) {
        debugPrint("Auto-backup skipped: No recovery passphrase stored in secure storage.");
        return;
      }

      // 4. Perform the backup
      debugPrint("Triggering daily automatic backup to Google Drive...");
      final success = await backupToGoogleDrive(
        googleSignIn: authProvider.googleSignIn,
        password: password,
      );

      if (success) {
        await storage.write(key: 'last_auto_backup_date', value: todayStr);
        debugPrint("Daily automatic backup succeeded!");
      } else {
        debugPrint("Daily automatic backup failed.");
      }
    } catch (e) {
      debugPrint("Error running automatic daily backup: $e");
    }
  }
}
