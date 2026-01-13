/// Printer connection type
enum PrinterConnectionType {
  wifi, // Network/WiFi printer
  bluetooth, // Bluetooth printer
  manualConnect, // Manual connection via MAC address
}

/// Printer source type - how the printer was discovered
enum PrinterSourceType {
  /// Built-in printer (e.g., Sunmi InnerPrinter)
  builtIn,

  /// Paired/bonded Bluetooth device (from system settings)
  paired,

  /// Newly discovered device (via discovery scan, not yet paired)
  discovered,

  /// Unknown source (default for backwards compatibility)
  unknown,
}

/// Printer device information
class PrinterDevice {
  final String id;
  final String name;
  final String? address; // IP address for WiFi, MAC address for Bluetooth
  final int? port; // Port for WiFi printers (usually 9100)
  final PrinterConnectionType type;
  final bool isConnected;
  final PrinterSourceType sourceType; // How the printer was discovered

  PrinterDevice({
    required this.id,
    required this.name,
    this.address,
    this.port,
    required this.type,
    this.isConnected = false,
    this.sourceType = PrinterSourceType.unknown,
  });

  PrinterDevice copyWith({
    String? id,
    String? name,
    String? address,
    int? port,
    PrinterConnectionType? type,
    bool? isConnected,
    PrinterSourceType? sourceType,
  }) {
    return PrinterDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      sourceType: sourceType ?? this.sourceType,
    );
  }

  /// Get the source label for UI display (Arabic)
  String get sourceLabel {
    switch (sourceType) {
      case PrinterSourceType.builtIn:
        return 'مدمجة';
      case PrinterSourceType.paired:
        return 'مقترنة';
      case PrinterSourceType.discovered:
        return 'جديدة';
      case PrinterSourceType.unknown:
        return '';
    }
  }

  /// Get the source label for UI display (English)
  String get sourceLabelEn {
    switch (sourceType) {
      case PrinterSourceType.builtIn:
        return 'Built-in';
      case PrinterSourceType.paired:
        return 'Paired';
      case PrinterSourceType.discovered:
        return 'New';
      case PrinterSourceType.unknown:
        return '';
    }
  }

  String get displayName {
    final label = sourceLabel.isNotEmpty ? ' [$sourceLabel]' : '';
    switch (type) {
      case PrinterConnectionType.wifi:
        return '$name (WiFi - ${address ?? "N/A"})$label';
      case PrinterConnectionType.bluetooth:
        return '$name (Bluetooth)$label';
      case PrinterConnectionType.manualConnect:
        return '$name (Manual - ${address ?? "N/A"})$label';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'port': port,
      'type': type.toString(),
      'isConnected': isConnected,
      'sourceType': sourceType.toString(),
    };
  }

  factory PrinterDevice.fromJson(Map<String, dynamic> json) {
    return PrinterDevice(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      port: json['port'],
      type: PrinterConnectionType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PrinterConnectionType.wifi,
      ),
      isConnected: json['isConnected'] ?? false,
      sourceType: PrinterSourceType.values.firstWhere(
        (e) => e.toString() == json['sourceType'],
        orElse: () => PrinterSourceType.unknown,
      ),
    );
  }
}
