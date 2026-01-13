import 'package:logger/logger.dart';

/// Centralized error mapping service
/// Maps technical errors to user-friendly messages
class PrinterErrorMapper {
  static final PrinterErrorMapper _instance = PrinterErrorMapper._internal();
  factory PrinterErrorMapper() => _instance;
  PrinterErrorMapper._internal();

  final Logger _logger = Logger();

  /// Map any exception or error to a user-friendly error
  PrinterError mapError(dynamic error, {String? context}) {
    _logger.e('🔴 Mapping error: $error (context: $context)');

    final errorString = error.toString().toLowerCase();

    // Bluetooth environment errors
    if (errorString.contains('bluetooth is not available') ||
        errorString.contains('bluetooth not supported')) {
      return PrinterError.bluetoothNotSupported();
    }

    if (errorString.contains('bluetooth is not enabled') ||
        errorString.contains('bluetooth is turned off') ||
        errorString.contains('bluetooth disabled') ||
        errorString.contains('bt_disabled')) {
      return PrinterError.bluetoothDisabled();
    }

    if (errorString.contains('location') &&
        (errorString.contains('disabled') ||
            errorString.contains('off') ||
            errorString.contains('not enabled'))) {
      return PrinterError.locationDisabled();
    }

    // Permission errors
    if (errorString.contains('permission') &&
        (errorString.contains('denied') ||
            errorString.contains('not granted') ||
            errorString.contains('required'))) {
      return PrinterError.permissionDenied();
    }

    // Connection errors
    if (errorString.contains('already connected') ||
        errorString.contains('device is busy') ||
        errorString.contains('resource busy')) {
      return PrinterError.printerAlreadyConnected();
    }

    if (errorString.contains('connection refused') ||
        errorString.contains('failed to connect')) {
      return PrinterError.connectionRefused();
    }

    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return PrinterError.connectionTimeout();
    }

    if (errorString.contains('not paired') ||
        errorString.contains('pairing required')) {
      return PrinterError.pairingRequired();
    }

    // Printer not reachable
    if (errorString.contains('not reachable') ||
        errorString.contains('unreachable') ||
        errorString.contains('offline') ||
        errorString.contains('powered off')) {
      return PrinterError.printerNotReachable();
    }

    // Write/communication errors
    if (errorString.contains('write failed') ||
        errorString.contains('send failed') ||
        errorString.contains('transmission failed')) {
      return PrinterError.writeFailed();
    }

    // Device discovery errors
    if (errorString.contains('no devices found') ||
        errorString.contains('no printers found')) {
      return PrinterError.noDevicesFound();
    }

    // Communication errors
    if (errorString.contains('socket') && errorString.contains('closed')) {
      return PrinterError.connectionLost();
    }

    if (errorString.contains('not connected') ||
        errorString.contains('no connection')) {
      return PrinterError.notConnected();
    }

    // Network errors (for WiFi printers)
    if (errorString.contains('network') ||
        errorString.contains('unreachable')) {
      return PrinterError.networkUnreachable();
    }

    // Incompatibility errors
    if (errorString.contains('incompatible') ||
        errorString.contains('not supported')) {
      return PrinterError.incompatibleDevice();
    }

    // Default fallback
    return PrinterError.unknown(error.toString());
  }
}

/// Structured printer error with user-friendly messages
class PrinterError {
  final String code;
  final String technicalMessage;
  final String userMessage;
  final String arabicTitle;
  final String arabicMessage;
  final List<String> suggestions;
  final bool isRecoverable;

  const PrinterError({
    required this.code,
    required this.technicalMessage,
    required this.userMessage,
    required this.arabicTitle,
    required this.arabicMessage,
    this.suggestions = const [],
    this.isRecoverable = true,
  });

  // ============================================================================
  // ENVIRONMENT ERRORS
  // ============================================================================

  factory PrinterError.bluetoothNotSupported() {
    return const PrinterError(
      code: 'E001_BT_NOT_SUPPORTED',
      technicalMessage: 'Bluetooth is not available on this device',
      userMessage: 'This device does not support Bluetooth',
      arabicTitle: 'البلوتوث غير مدعوم',
      arabicMessage:
          'جهازك لا يدعم البلوتوث.\nلا يمكن الاتصال بطابعات البلوتوث.',
      suggestions: ['استخدم طابعة WiFi بدلاً من ذلك'],
      isRecoverable: false,
    );
  }

  factory PrinterError.bluetoothDisabled() {
    return const PrinterError(
      code: 'E002_BT_DISABLED',
      technicalMessage: 'Bluetooth is turned off',
      userMessage: 'Bluetooth is turned off',
      arabicTitle: 'البلوتوث مغلق',
      arabicMessage: 'البلوتوث مغلق حالياً.\nيرجى تشغيله من الإعدادات.',
      suggestions: [
        'افتح إعدادات الجهاز',
        'قم بتشغيل البلوتوث',
        'ارجع وحاول مرة أخرى',
      ],
      isRecoverable: true,
    );
  }

  factory PrinterError.locationDisabled() {
    return const PrinterError(
      code: 'E003_LOCATION_DISABLED',
      technicalMessage: 'Location services are disabled',
      userMessage: 'Location must be enabled to discover Bluetooth devices',
      arabicTitle: 'خدمات الموقع مغلقة',
      arabicMessage:
          'يجب تفعيل خدمات الموقع للبحث عن طابعات البلوتوث.\n(هذا مطلب من نظام أندرويد)',
      suggestions: [
        'افتح إعدادات الجهاز',
        'قم بتشغيل خدمات الموقع (GPS)',
        'ارجع وحاول مرة أخرى',
      ],
      isRecoverable: true,
    );
  }

  factory PrinterError.permissionDenied() {
    return const PrinterError(
      code: 'E004_PERMISSION_DENIED',
      technicalMessage: 'Bluetooth permissions not granted',
      userMessage: 'Permission denied. Please allow Nearby Devices.',
      arabicTitle: 'صلاحيات البلوتوث مطلوبة',
      arabicMessage: 'يجب منح صلاحيات البلوتوث للبحث عن الطابعات.',
      suggestions: [
        'اسمح بصلاحيات Bluetooth Scan',
        'اسمح بصلاحيات Bluetooth Connect',
        'اسمح بصلاحيات الموقع',
      ],
      isRecoverable: true,
    );
  }

  // ============================================================================
  // CONNECTION ERRORS
  // ============================================================================

  factory PrinterError.printerAlreadyConnected() {
    return const PrinterError(
      code: 'E101_ALREADY_CONNECTED',
      technicalMessage: 'Printer is already connected to another device',
      userMessage: 'This printer is currently connected to another device',
      arabicTitle: 'الطابعة متصلة بجهاز آخر',
      arabicMessage:
          'هذه الطابعة متصلة حالياً بجهاز آخر.\nيرجى قطع الاتصال من الجهاز الآخر أولاً.',
      suggestions: [
        'افصل الطابعة من الجهاز الآخر',
        'أعد تشغيل الطابعة',
        'حاول مرة أخرى',
      ],
      isRecoverable: true,
    );
  }

  factory PrinterError.connectionRefused() {
    return const PrinterError(
      code: 'E102_CONNECTION_REFUSED',
      technicalMessage: 'Connection refused by printer',
      userMessage: 'Failed to connect to printer',
      arabicTitle: 'فشل الاتصال بالطابعة',
      arabicMessage: 'تعذر الاتصال بالطابعة.\nتأكد من أن الطابعة قريبة ومشغلة.',
      suggestions: [
        'تأكد من أن الطابعة مشغلة',
        'اقترب من الطابعة',
        'أعد تشغيل الطابعة',
        'حاول مرة أخرى',
      ],
      isRecoverable: true,
    );
  }

  factory PrinterError.connectionTimeout() {
    return const PrinterError(
      code: 'E103_CONNECTION_TIMEOUT',
      technicalMessage: 'Connection attempt timed out',
      userMessage: 'Connection timed out',
      arabicTitle: 'انتهت مهلة الاتصال',
      arabicMessage:
          'استغرق الاتصال وقتاً طويلاً.\nتأكد من أن الطابعة قريبة ومشغلة.',
      suggestions: [
        'اقترب من الطابعة',
        'تأكد من أن الطابعة مشغلة',
        'حاول مرة أخرى',
      ],
      isRecoverable: true,
    );
  }

  factory PrinterError.pairingRequired() {
    return const PrinterError(
      code: 'E104_PAIRING_REQUIRED',
      technicalMessage: 'Device requires pairing before connection',
      userMessage: 'Printer must be paired first',
      arabicTitle: 'يجب إقران الطابعة أولاً',
      arabicMessage: 'يجب إقران الطابعة مع الجهاز أولاً من إعدادات البلوتوث.',
      suggestions: [
        'افتح إعدادات البلوتوث في الجهاز',
        'ابحث عن الطابعة',
        'اضغط على "إقران" أو "Pair"',
        'ارجع للتطبيق وحاول مرة أخرى',
      ],
      isRecoverable: true,
    );
  }

  factory PrinterError.connectionLost() {
    return const PrinterError(
      code: 'E105_CONNECTION_LOST',
      technicalMessage: 'Connection to printer was lost',
      userMessage: 'Lost connection to printer',
      arabicTitle: 'انقطع الاتصال بالطابعة',
      arabicMessage:
          'انقطع الاتصال بالطابعة.\nتأكد من أن الطابعة قريبة ومشغلة.',
      suggestions: [
        'تأكد من أن الطابعة مشغلة',
        'اقترب من الطابعة',
        'أعد الاتصال',
      ],
      isRecoverable: true,
    );
  }

  factory PrinterError.notConnected() {
    return const PrinterError(
      code: 'E106_NOT_CONNECTED',
      technicalMessage: 'No printer is currently connected',
      userMessage: 'No printer connected',
      arabicTitle: 'لا توجد طابعة متصلة',
      arabicMessage: 'لا توجد طابعة متصلة حالياً.\nيرجى الاتصال بطابعة أولاً.',
      suggestions: ['انتقل إلى إعدادات الطابعة', 'اختر طابعة', 'اتصل بها'],
      isRecoverable: true,
    );
  }

  factory PrinterError.printerNotReachable() {
    return const PrinterError(
      code: 'E107_PRINTER_NOT_REACHABLE',
      technicalMessage: 'Printer is not reachable or powered off',
      userMessage: 'Cannot reach printer',
      arabicTitle: 'لا يمكن الوصول للطابعة',
      arabicMessage:
          'لا يمكن الوصول للطابعة.\nتأكد من أن الطابعة مشغلة وقريبة من الجهاز.',
      suggestions: [
        'تأكد من تشغيل الطابعة',
        'اقترب من الطابعة',
        'تحقق من بطارية الطابعة (إن وجدت)',
        'أعد تشغيل الطابعة',
      ],
      isRecoverable: true,
    );
  }

  // ============================================================================
  // DISCOVERY ERRORS
  // ============================================================================

  factory PrinterError.noDevicesFound() {
    return const PrinterError(
      code: 'E201_NO_DEVICES_FOUND',
      technicalMessage: 'No Bluetooth devices discovered',
      userMessage: 'No printers found nearby',
      arabicTitle: 'لم يتم العثور على طابعات',
      arabicMessage:
          'لم يتم العثور على طابعات بلوتوث قريبة.\nتأكد من أن الطابعة مشغلة ومقترنة.',
      suggestions: [
        'شغّل الطابعة',
        'اقترن بالطابعة من إعدادات البلوتوث',
        'اقترب من الطابعة',
        'حاول البحث مرة أخرى',
      ],
      isRecoverable: true,
    );
  }

  // ============================================================================
  // COMMUNICATION ERRORS
  // ============================================================================

  factory PrinterError.sendDataFailed() {
    return const PrinterError(
      code: 'E301_SEND_FAILED',
      technicalMessage: 'Failed to send data to printer',
      userMessage: 'Failed to send data to printer',
      arabicTitle: 'فشل إرسال البيانات',
      arabicMessage:
          'تعذر إرسال البيانات للطابعة.\nقد تكون الطابعة مشغولة أو انقطع الاتصال.',
      suggestions: [
        'تأكد من اتصال الطابعة',
        'تأكد من وجود ورق في الطابعة',
        'أعد تشغيل الطابعة',
        'حاول مرة أخرى',
      ],
      isRecoverable: true,
    );
  }

  factory PrinterError.writeFailed() {
    return const PrinterError(
      code: 'E302_WRITE_FAILED',
      technicalMessage: 'Failed to write data to printer',
      userMessage: 'Failed to write to printer',
      arabicTitle: 'فشلت الكتابة إلى الطابعة',
      arabicMessage:
          'تعذرت الكتابة إلى الطابعة.\nقد يكون الاتصال غير مستقر.',
      suggestions: [
        'تحقق من استقرار الاتصال',
        'اقترب من الطابعة',
        'أعد الاتصال بالطابعة',
        'حاول مرة أخرى',
      ],
      isRecoverable: true,
    );
  }

  // ============================================================================
  // NETWORK ERRORS (WiFi printers)
  // ============================================================================

  factory PrinterError.networkUnreachable() {
    return const PrinterError(
      code: 'E401_NETWORK_UNREACHABLE',
      technicalMessage: 'Network printer is unreachable',
      userMessage: 'Cannot reach network printer',
      arabicTitle: 'لا يمكن الوصول للطابعة',
      arabicMessage:
          'لا يمكن الوصول لطابعة الشبكة.\nتأكد من اتصالك بنفس الشبكة.',
      suggestions: [
        'تأكد من اتصال الجهاز بالواي فاي',
        'تأكد من اتصال الطابعة بنفس الشبكة',
        'تحقق من عنوان IP للطابعة',
      ],
      isRecoverable: true,
    );
  }

  // ============================================================================
  // COMPATIBILITY ERRORS
  // ============================================================================

  factory PrinterError.incompatibleDevice() {
    return const PrinterError(
      code: 'E501_INCOMPATIBLE',
      technicalMessage: 'Printer model is not fully compatible',
      userMessage: 'This printer model is not fully compatible',
      arabicTitle: 'طابعة غير متوافقة',
      arabicMessage: 'هذا النموذج من الطابعة قد لا يعمل بشكل صحيح مع التطبيق.',
      suggestions: ['استخدم طابعة حرارية متوافقة', 'جرب طابعة أخرى'],
      isRecoverable: false,
    );
  }

  // ============================================================================
  // UNKNOWN ERRORS
  // ============================================================================

  factory PrinterError.unknown(String technicalDetails) {
    return PrinterError(
      code: 'E999_UNKNOWN',
      technicalMessage: technicalDetails,
      userMessage: 'An unexpected error occurred',
      arabicTitle: 'خطأ غير متوقع',
      arabicMessage: 'حدث خطأ غير متوقع.\nيرجى المحاولة مرة أخرى.',
      suggestions: [
        'أعد تشغيل التطبيق',
        'أعد تشغيل الطابعة',
        'اتصل بالدعم الفني',
      ],
      isRecoverable: true,
    );
  }

  @override
  String toString() {
    return '[$code] $arabicTitle: $arabicMessage';
  }
}
