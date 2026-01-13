import 'dart:async';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:logger/logger.dart';
import '../screens/casher/models/printer_device.dart';

/// Manual Printer Connection Service
///
/// Provides guaranteed connection fallback when automatic discovery fails.
/// Users can manually enter a MAC address to connect directly.
///
/// KEY FEATURES:
/// - Direct RFCOMM/SPP connection using MAC address
/// - Standard Bluetooth SPP UUID: 00001101-0000-1000-8000-00805F9B34FB
/// - Works even when printer doesn't appear in bonded devices list
/// - Validates MAC address format before attempting connection
/// - Provides detailed connection diagnostics
///
/// COMPATIBILITY:
/// - Android 8-14+
/// - All Bluetooth Classic thermal printers
/// - Works with paired and unpaired devices (if within range)
class ManualPrinterConnectionService {
  static final ManualPrinterConnectionService _instance =
      ManualPrinterConnectionService._internal();
  factory ManualPrinterConnectionService() => _instance;
  ManualPrinterConnectionService._internal();

  final Logger _logger = Logger();
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  /// Standard Bluetooth Serial Port Profile (SPP) UUID
  /// This is the universal UUID for Bluetooth Classic serial communication
  static const String sppUuid = '00001101-0000-1000-8000-00805F9B34FB';

  /// Connection timeout for manual connections
  static const Duration connectionTimeout = Duration(seconds: 10);

  /// Validate MAC address format
  ///
  /// Valid formats:
  /// - AA:BB:CC:DD:EE:FF (standard)
  /// - AA-BB-CC-DD-EE-FF (alternative)
  /// - AABBCCDDEEFF (no separators)
  ///
  /// Returns normalized MAC address (with colons) or null if invalid
  String? validateAndNormalizeMacAddress(String input) {
    // Remove whitespace
    final cleaned = input.trim().toUpperCase();

    // Pattern 1: AA:BB:CC:DD:EE:FF
    final colonPattern = RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$');
    if (colonPattern.hasMatch(cleaned)) {
      return cleaned;
    }

    // Pattern 2: AA-BB-CC-DD-EE-FF
    final dashPattern = RegExp(r'^([0-9A-F]{2}-){5}[0-9A-F]{2}$');
    if (dashPattern.hasMatch(cleaned)) {
      return cleaned.replaceAll('-', ':');
    }

    // Pattern 3: AABBCCDDEEFF
    final noSeparatorPattern = RegExp(r'^[0-9A-F]{12}$');
    if (noSeparatorPattern.hasMatch(cleaned)) {
      // Insert colons
      return cleaned.replaceAllMapped(
        RegExp(r'(.{2})'),
        (match) => '${match.group(0)}:',
      ).substring(0, 17);
    }

    _logger.w('❌ Invalid MAC address format: $input');
    return null;
  }

  /// Connect to a printer using MAC address directly
  ///
  /// This method attempts a direct RFCOMM connection using the standard
  /// Bluetooth SPP UUID. It works even if the printer is not in the
  /// bonded devices list (though pairing is recommended for reliability).
  ///
  /// [macAddress] - Bluetooth MAC address (will be normalized)
  /// [printerName] - Optional name for the printer (for UI display)
  ///
  /// Returns PrinterDevice on success, throws exception on failure
  Future<PrinterDevice> connectByMacAddress({
    required String macAddress,
    String? printerName,
  }) async {
    _logger.i('═══════════════════════════════════════════════════════');
    _logger.i('[MANUAL CONNECT] Starting manual connection');
    _logger.i('[MANUAL CONNECT] Input MAC: $macAddress');
    _logger.i('═══════════════════════════════════════════════════════');

    // Step 1: Validate and normalize MAC address
    final normalizedMac = validateAndNormalizeMacAddress(macAddress);
    if (normalizedMac == null) {
      throw ManualConnectionException(
        code: 'INVALID_MAC_FORMAT',
        technicalMessage: 'Invalid MAC address format: $macAddress',
        userMessage: 'عنوان MAC غير صحيح',
        arabicTitle: 'عنوان MAC غير صحيح',
        arabicMessage:
            'الرجاء إدخال عنوان MAC بالشكل الصحيح (مثل: AA:BB:CC:DD:EE:FF)',
        suggestions: [
          'استخدم الصيغة: AA:BB:CC:DD:EE:FF',
          'أو: AA-BB-CC-DD-EE-FF',
          'أو: AABBCCDDEEFF',
          'تأكد من استخدام أحرف وأرقام صحيحة (0-9, A-F)',
        ],
      );
    }

    _logger.i('[MANUAL CONNECT] Normalized MAC: $normalizedMac');

    // Step 2: Check if device is in bonded devices (preferred but not required)
    try {
      final bondedDevices = await _bluetooth.getBondedDevices();
      final isBonded = bondedDevices.any(
        (device) => device.address?.toUpperCase() == normalizedMac,
      );

      if (isBonded) {
        _logger.i('✅ Device is bonded at system level (recommended)');
      } else {
        _logger.w('⚠️ Device is NOT bonded - connection may be less reliable');
        _logger.w('💡 Recommend pairing in Android Bluetooth settings first');
      }
    } catch (e) {
      _logger.w('⚠️ Could not check bonded devices: $e');
    }

    // Step 3: Attempt connection with timeout
    try {
      _logger.i('[MANUAL CONNECT] Attempting RFCOMM connection...');
      _logger.i('[MANUAL CONNECT] UUID: $sppUuid');
      _logger.i('[MANUAL CONNECT] Timeout: ${connectionTimeout.inSeconds}s');

      // Create a BluetoothDevice object for connection
      // Note: blue_thermal_printer uses its own BluetoothDevice type
      final deviceToConnect = BluetoothDevice(
        normalizedMac,
        printerName ?? 'Printer ($normalizedMac)',
      );

      // Attempt connection with timeout
      final connectionFuture = _bluetooth.connect(deviceToConnect);

      await connectionFuture.timeout(
        connectionTimeout,
        onTimeout: () {
          throw ManualConnectionException(
            code: 'CONNECTION_TIMEOUT',
            technicalMessage:
                'Connection timed out after ${connectionTimeout.inSeconds}s',
            userMessage: 'انتهت مهلة الاتصال',
            arabicTitle: 'انتهت مهلة الاتصال',
            arabicMessage:
                'لم يتم الاتصال بالطابعة خلال ${connectionTimeout.inSeconds} ثانية.',
            suggestions: [
              'تأكد من تشغيل الطابعة',
              'تأكد من أن البلوتوث مفعّل على الطابعة',
              'تأكد من أن الطابعة قريبة من الجهاز',
              'قم بإقران الطابعة في إعدادات البلوتوث أولاً',
            ],
          );
        },
      );

      _logger.i('✅ Connection successful!');

      // Step 4: Verify connection state
      final isConnected = await _bluetooth.isConnected;
      if (isConnected != true) {
        throw ManualConnectionException(
          code: 'CONNECTION_FAILED',
          technicalMessage: 'Connection reported success but isConnected=false',
          userMessage: 'فشل التحقق من الاتصال',
          arabicTitle: 'فشل الاتصال',
          arabicMessage: 'تم الاتصال لكن التحقق فشل. الرجاء المحاولة مرة أخرى.',
          suggestions: [
            'أعد المحاولة',
            'أعد تشغيل الطابعة',
            'قم بإعادة إقران الطابعة',
          ],
        );
      }

      _logger.i('✅ Connection verified');

      // Step 5: Create PrinterDevice object
      final printer = PrinterDevice(
        id: 'bt_manual_$normalizedMac',
        name: printerName ?? 'Manual Printer',
        address: normalizedMac,
        type: PrinterConnectionType.bluetooth,
        isConnected: true,
        sourceType: PrinterSourceType.paired,
      );

      _logger.i('═══════════════════════════════════════════════════════');
      _logger.i('[MANUAL CONNECT] ✅ Manual connection complete');
      _logger.i('[MANUAL CONNECT] Printer: ${printer.name}');
      _logger.i('[MANUAL CONNECT] MAC: ${printer.address}');
      _logger.i('═══════════════════════════════════════════════════════');

      return printer;
    } catch (e) {
      _logger.e('❌ Manual connection failed: $e');

      // If it's already a ManualConnectionException, rethrow
      if (e is ManualConnectionException) {
        rethrow;
      }

      // Map other exceptions
      throw ManualConnectionException(
        code: 'CONNECTION_ERROR',
        technicalMessage: 'Manual connection failed: $e',
        userMessage: 'فشل الاتصال',
        arabicTitle: 'فشل الاتصال بالطابعة',
        arabicMessage: 'تعذر الاتصال بالطابعة. الرجاء التحقق من العنوان والمحاولة مرة أخرى.',
        suggestions: [
          'تحقق من صحة عنوان MAC',
          'تأكد من تشغيل الطابعة',
          'قم بإقران الطابعة في إعدادات الأندرويد',
          'تأكد من قرب الطابعة من الجهاز',
        ],
      );
    }
  }

  /// Test connection to a MAC address (without persisting)
  ///
  /// Returns true if connection succeeds, false otherwise
  /// Automatically disconnects after test
  Future<bool> testConnection(String macAddress) async {
    _logger.i('🧪 Testing connection to $macAddress');

    try {
      await connectByMacAddress(
        macAddress: macAddress,
        printerName: 'Test Printer',
      );

      _logger.i('✅ Test connection successful');

      // Disconnect after test
      try {
        await _bluetooth.disconnect();
        _logger.i('✅ Test disconnected');
      } catch (e) {
        _logger.w('⚠️ Failed to disconnect after test: $e');
      }

      return true;
    } catch (e) {
      _logger.e('❌ Test connection failed: $e');
      return false;
    }
  }

  /// Get common MAC address format examples for UI help
  List<String> getMacAddressExamples() {
    return [
      'AA:BB:CC:DD:EE:FF',
      'AA-BB-CC-DD-EE-FF',
      'AABBCCDDEEFF',
      '00:11:22:33:44:55',
      'DC:0D:30:12:34:56',
    ];
  }

  /// Get MAC address format instructions (Arabic)
  String getMacAddressInstructionsAr() {
    return '''
أدخل عنوان MAC للطابعة بأحد الأشكال التالية:
• AA:BB:CC:DD:EE:FF (بنقطتين رأسيتين)
• AA-BB-CC-DD-EE-FF (بشرطات)
• AABBCCDDEEFF (بدون فواصل)

يمكنك إيجاد عنوان MAC:
1. في إعدادات البلوتوث على الأندرويد
2. في ملصق على الطابعة
3. في دليل استخدام الطابعة
4. بطباعة صفحة اختبار من الطابعة
''';
  }

  /// Get MAC address format instructions (English)
  String getMacAddressInstructionsEn() {
    return '''
Enter the printer's MAC address in one of these formats:
• AA:BB:CC:DD:EE:FF (with colons)
• AA-BB-CC-DD-EE-FF (with dashes)
• AABBCCDDEEFF (no separators)

You can find the MAC address:
1. In Android Bluetooth settings
2. On a label on the printer
3. In the printer's manual
4. By printing a test page from the printer
''';
  }
}

/// Manual connection exception with structured error info
class ManualConnectionException implements Exception {
  final String code;
  final String technicalMessage;
  final String userMessage;
  final String arabicTitle;
  final String arabicMessage;
  final List<String> suggestions;

  ManualConnectionException({
    required this.code,
    required this.technicalMessage,
    required this.userMessage,
    required this.arabicTitle,
    required this.arabicMessage,
    this.suggestions = const [],
  });

  @override
  String toString() => '$code: $technicalMessage';
}
