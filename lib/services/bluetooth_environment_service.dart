import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'permission_service.dart';

/// Pre-flight check results for Bluetooth environment
class BluetoothEnvironmentCheck {
  final bool isBluetoothAvailable;
  final bool isBluetoothEnabled;
  final bool isLocationEnabled;
  final bool hasPermissions;
  final List<String> missingRequirements;
  final BluetoothEnvironmentError? error;

  const BluetoothEnvironmentCheck({
    required this.isBluetoothAvailable,
    required this.isBluetoothEnabled,
    required this.isLocationEnabled,
    required this.hasPermissions,
    required this.missingRequirements,
    this.error,
  });

  bool get isReady => missingRequirements.isEmpty && error == null;

  String get readableMessage {
    if (isReady) return 'جاهز للبحث عن الطابعات';

    if (error != null) return error!.userMessage;

    if (missingRequirements.isNotEmpty) {
      return 'المتطلبات المفقودة:\n${missingRequirements.join('\n')}';
    }

    return 'فشل التحقق من البيئة';
  }
}

/// Bluetooth environment validation service
/// Performs pre-flight checks before scanning or connecting
class BluetoothEnvironmentService {
  static final BluetoothEnvironmentService _instance =
      BluetoothEnvironmentService._internal();
  factory BluetoothEnvironmentService() => _instance;
  BluetoothEnvironmentService._internal();

  final Logger _logger = Logger();
  final PermissionService _permissionService = PermissionService();
  final BlueThermalPrinter _bluetoothPrinter = BlueThermalPrinter.instance;

  /// Perform comprehensive pre-flight check
  /// Returns detailed results about Bluetooth environment
  Future<BluetoothEnvironmentCheck> performPreFlightCheck() async {
    _logger.i('🔍 Starting Bluetooth environment pre-flight check...');

    final missingRequirements = <String>[];
    BluetoothEnvironmentError? error;

    // 1. Check if Bluetooth is available on device
    bool isBluetoothAvailable = false;
    try {
      final available = await _bluetoothPrinter.isAvailable;
      isBluetoothAvailable = available ?? false;

      if (!isBluetoothAvailable) {
        _logger.e('❌ Bluetooth is not available on this device');
        missingRequirements.add('• جهازك لا يدعم البلوتوث');
        error = BluetoothEnvironmentError.bluetoothNotSupported();
      } else {
        _logger.i('✅ Bluetooth is available');
      }
    } catch (e) {
      _logger.e('❌ Failed to check Bluetooth availability: $e');
      isBluetoothAvailable = false;
      error = BluetoothEnvironmentError.bluetoothNotSupported();
    }

    // 2. Check if Bluetooth is enabled
    bool isBluetoothEnabled = false;
    if (isBluetoothAvailable) {
      try {
        final enabled = await _bluetoothPrinter.isOn;
        isBluetoothEnabled = enabled ?? false;

        if (!isBluetoothEnabled) {
          _logger.w('⚠️ Bluetooth is disabled');
          missingRequirements.add('• البلوتوث مغلق - يرجى تشغيله');
          error = BluetoothEnvironmentError.bluetoothDisabled();
        } else {
          _logger.i('✅ Bluetooth is enabled');
        }
      } catch (e) {
        _logger.e('❌ Failed to check Bluetooth state: $e');
        isBluetoothEnabled = false;
      }
    }

    // 3. Check if Location is enabled (required for Bluetooth discovery on Android < 12)
    bool isLocationEnabled = false;
    try {
      // Get Android SDK version to determine if location is required
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      final locationStatus = await Permission.location.serviceStatus;
      isLocationEnabled = locationStatus.isEnabled;

      // Location is only strictly required on Android < 12 (API < 31)
      // On Android 12+, BLUETOOTH_SCAN with neverForLocation flag is sufficient
      if (!isLocationEnabled && sdkInt < 31) {
        _logger.w('⚠️ Location services are disabled (required on Android < 12)');
        missingRequirements.add(
          '• خدمات الموقع مغلقة - مطلوبة للبحث عن البلوتوث على أندرويد < 12',
        );
        error ??= BluetoothEnvironmentError.locationDisabled();
      } else if (isLocationEnabled) {
        _logger.i('✅ Location services are enabled');
      } else {
        _logger.i('ℹ️ Location disabled but not required on Android 12+');
      }
    } catch (e) {
      _logger.e('❌ Failed to check location status: $e');
      isLocationEnabled = false;
    }

    // 4. Check if required permissions are granted
    bool hasPermissions = false;
    try {
      hasPermissions = await _permissionService.checkBluetoothPermissions();

      if (!hasPermissions) {
        _logger.w('⚠️ Bluetooth permissions not granted');
        missingRequirements.add('• صلاحيات البلوتوث غير مفعلة');
        error ??= BluetoothEnvironmentError.permissionsNotGranted();
      } else {
        _logger.i('✅ Bluetooth permissions are granted');
      }
    } catch (e) {
      _logger.e('❌ Failed to check permissions: $e');
      hasPermissions = false;
    }

    final result = BluetoothEnvironmentCheck(
      isBluetoothAvailable: isBluetoothAvailable,
      isBluetoothEnabled: isBluetoothEnabled,
      isLocationEnabled: isLocationEnabled,
      hasPermissions: hasPermissions,
      missingRequirements: missingRequirements,
      error: error,
    );

    if (result.isReady) {
      _logger.i('✅ Pre-flight check PASSED - Environment is ready');
    } else {
      _logger.w(
        '⚠️ Pre-flight check FAILED - ${missingRequirements.length} requirement(s) missing',
      );
    }

    return result;
  }

  /// Quick check if environment is ready (cached for performance)
  Future<bool> isEnvironmentReady() async {
    try {
      final check = await performPreFlightCheck();
      return check.isReady;
    } catch (e) {
      _logger.e('❌ Failed to check environment: $e');
      return false;
    }
  }
}

/// Structured Bluetooth environment errors
class BluetoothEnvironmentError {
  final String code;
  final String technicalMessage;
  final String userMessage;
  final String arabicTitle;
  final String arabicMessage;
  final List<String> suggestions;

  const BluetoothEnvironmentError({
    required this.code,
    required this.technicalMessage,
    required this.userMessage,
    required this.arabicTitle,
    required this.arabicMessage,
    this.suggestions = const [],
  });

  factory BluetoothEnvironmentError.bluetoothNotSupported() {
    return const BluetoothEnvironmentError(
      code: 'BT_NOT_SUPPORTED',
      technicalMessage: 'Bluetooth is not available on this device',
      userMessage: 'This device does not support Bluetooth',
      arabicTitle: 'البلوتوث غير مدعوم',
      arabicMessage: 'جهازك لا يدعم البلوتوث. لا يمكن الاتصال بطابعات بلوتوث.',
      suggestions: ['استخدم طابعة WiFi بدلاً من ذلك'],
    );
  }

  factory BluetoothEnvironmentError.bluetoothDisabled() {
    return const BluetoothEnvironmentError(
      code: 'BT_DISABLED',
      technicalMessage: 'Bluetooth is turned off',
      userMessage: 'Bluetooth is turned off. Please enable it and try again.',
      arabicTitle: 'البلوتوث مغلق',
      arabicMessage:
          'البلوتوث مغلق حالياً. يرجى تشغيل البلوتوث من الإعدادات والمحاولة مرة أخرى.',
      suggestions: [
        'افتح إعدادات الجهاز',
        'قم بتشغيل البلوتوث',
        'ارجع للتطبيق وحاول مرة أخرى',
      ],
    );
  }

  factory BluetoothEnvironmentError.locationDisabled() {
    return const BluetoothEnvironmentError(
      code: 'LOCATION_DISABLED',
      technicalMessage: 'Location services are disabled',
      userMessage:
          'Location services must be enabled to search for Bluetooth printers.',
      arabicTitle: 'خدمات الموقع مغلقة',
      arabicMessage:
          'يجب تفعيل خدمات الموقع للبحث عن طابعات البلوتوث. هذا مطلب من نظام أندرويد.',
      suggestions: [
        'افتح إعدادات الجهاز',
        'قم بتشغيل خدمات الموقع (GPS)',
        'ارجع للتطبيق وحاول مرة أخرى',
      ],
    );
  }

  factory BluetoothEnvironmentError.permissionsNotGranted() {
    return const BluetoothEnvironmentError(
      code: 'PERMISSIONS_MISSING',
      technicalMessage: 'Required Bluetooth permissions not granted',
      userMessage: 'Bluetooth permissions are required to scan for printers.',
      arabicTitle: 'صلاحيات البلوتوث مطلوبة',
      arabicMessage: 'يجب منح صلاحيات البلوتوث للبحث عن الطابعات.',
      suggestions: [
        'اسمح بصلاحيات Bluetooth Scan',
        'اسمح بصلاحيات Bluetooth Connect',
        'اسمح بصلاحيات الموقع',
      ],
    );
  }
}
