class Business {
  final int? id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String gstOrTin;
  final String upiId;
  final String? logoPath;
  final String currency;
  final String? recoveryPasswordHash;
  final String? backupEmail;
  final DateTime? lastBackupTime;
  final String themeMode; // 'light', 'dark', or 'system'
  final String receiptHeader;
  final String receiptFooter;

  Business({
    this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.gstOrTin,
    required this.upiId,
    this.logoPath,
    this.currency = '₹',
    this.recoveryPasswordHash,
    this.backupEmail,
    this.lastBackupTime,
    this.themeMode = 'system',
    this.receiptHeader = '',
    this.receiptFooter = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'gstOrTin': gstOrTin,
      'upiId': upiId,
      'logoPath': logoPath,
      'currency': currency,
      'recoveryPasswordHash': recoveryPasswordHash,
      'backupEmail': backupEmail,
      'lastBackupTime': lastBackupTime?.toIso8601String(),
      'themeMode': themeMode,
      'receiptHeader': receiptHeader,
      'receiptFooter': receiptFooter,
    };
  }

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      gstOrTin: map['gstOrTin'] as String? ?? '',
      upiId: map['upiId'] as String? ?? '',
      logoPath: map['logoPath'] as String?,
      currency: map['currency'] as String? ?? '₹',
      recoveryPasswordHash: map['recoveryPasswordHash'] as String?,
      backupEmail: map['backupEmail'] as String?,
      lastBackupTime: map['lastBackupTime'] != null
          ? DateTime.tryParse(map['lastBackupTime'] as String)
          : null,
      themeMode: map['themeMode'] as String? ?? 'system',
      receiptHeader: map['receiptHeader'] as String? ?? '',
      receiptFooter: map['receiptFooter'] as String? ?? '',
    );
  }

  Business copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstOrTin,
    String? upiId,
    String? logoPath,
    String? currency,
    String? recoveryPasswordHash,
    String? backupEmail,
    DateTime? lastBackupTime,
    String? themeMode,
    String? receiptHeader,
    String? receiptFooter,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstOrTin: gstOrTin ?? this.gstOrTin,
      upiId: upiId ?? this.upiId,
      logoPath: logoPath ?? this.logoPath,
      currency: currency ?? this.currency,
      recoveryPasswordHash: recoveryPasswordHash ?? this.recoveryPasswordHash,
      backupEmail: backupEmail ?? this.backupEmail,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
      themeMode: themeMode ?? this.themeMode,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
    );
  }
}
