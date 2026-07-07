class PrinterSettings {
  final int? id;
  final String name;
  final String type; // 'bluetooth' or 'network'
  final String address; // MAC address for Bluetooth, or IP:Port (e.g. '192.168.1.100') for TCP Wi-Fi
  final int paperWidth; // 58 or 80 (mm)

  PrinterSettings({
    this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.paperWidth,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'address': address,
      'paperWidth': paperWidth,
    };
  }

  factory PrinterSettings.fromMap(Map<String, dynamic> map) {
    return PrinterSettings(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'bluetooth',
      address: map['address'] as String? ?? '',
      paperWidth: map['paperWidth'] as int? ?? 58,
    );
  }

  PrinterSettings copyWith({
    int? id,
    String? name,
    String? type,
    String? address,
    int? paperWidth,
  }) {
    return PrinterSettings(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      paperWidth: paperWidth ?? this.paperWidth,
    );
  }
}
