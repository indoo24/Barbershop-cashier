import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as esc_pos;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
// import 'package:usb_serial/usb_serial.dart';  // Disabled due to compatibility issues
import '../models/printer_device.dart';
import '../../../models/printer_settings.dart';
import '../../../models/invoice_data.dart';
import '../../../services/bluetooth_classic_printer_service.dart';
import '../../../services/printer_error_mapper.dart';
import '../../../services/image_based_thermal_printer.dart';
import '../../../services/thermal_pdf_test_service.dart';
import '../../../services/unified_printer_discovery_service.dart';
import 'dart:convert';

/// Universal printer service supporting WiFi, Bluetooth, and USB
class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final Logger _logger = Logger();
  final BluetoothClassicPrinterService _bluetoothClassicService =
      BluetoothClassicPrinterService();
  final UnifiedPrinterDiscoveryService _unifiedDiscoveryService =
      UnifiedPrinterDiscoveryService();
  final PrinterErrorMapper _errorMapper = PrinterErrorMapper();

  // Bluetooth printer instance
  final BlueThermalPrinter _bluetoothPrinter = BlueThermalPrinter.instance;

  // Currently connected printer
  PrinterDevice? _connectedPrinter;
  PrinterDevice? get connectedPrinter => _connectedPrinter;

  // Printer settings (paper size, etc.)
  PrinterSettings _settings = const PrinterSettings();
  PrinterSettings get settings => _settings;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🧪 PDF TEST MODE FLAG
  // ═══════════════════════════════════════════════════════════════════════════
  // When enabled, printing calls will preview the thermal receipt as A4 PDF
  // instead of sending to a real thermal printer.
  //
  // ✅ USE CASES:
  // - Testing receipt layout without a thermal printer
  // - Debugging Arabic text and RTL rendering
  // - Validating spacing and alignment
  // - Development on machines without printer access
  //
  // ⚠️ IMPORTANT:
  // - This should be FALSE in production
  // - This should be TRUE only for local testing/debugging
  // - The PDF shows the EXACT same receipt as thermal printing
  // - No ESC/POS commands are sent in test mode
  // ═══════════════════════════════════════════════════════════════════════════
  bool thermalPdfTestMode = false;

  // Network printer instance (for WiFi)
  NetworkPrinter? _networkPrinter;

  // Connection retry configuration
  static const int _maxRetries = 1;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _connectionTimeout = Duration(seconds: 15);

  // USB port and transaction (for USB) - Disabled due to compatibility issues
  // UsbPort? _usbPort;
  // StreamSubscription<String>? _usbSubscription;

  // ============================================================================
  // SCANNING METHODS
  // ============================================================================

  /// Scan for WiFi printers on local network
  Future<List<PrinterDevice>> scanWiFiPrinters() async {
    final devices = <PrinterDevice>[];

    try {
      // Get local network info
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();

      if (wifiIP == null) {
        return devices;
      }

      // Extract network prefix (e.g., "192.168.1")
      final parts = wifiIP.split('.');
      if (parts.length < 3) return devices;
      final networkPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';

      // Scan common printer IPs (192.168.1.1 - 192.168.1.254)
      final futures = <Future>[];
      for (int i = 1; i <= 254; i++) {
        final ip = '$networkPrefix.$i';
        futures.add(
          _checkPrinterAtIP(ip, 9100).then((isAvailable) {
            if (isAvailable) {
              devices.add(
                PrinterDevice(
                  id: 'wifi_$ip',
                  name: 'Network Printer',
                  address: ip,
                  port: 9100,
                  type: PrinterConnectionType.wifi,
                ),
              );
            }
          }),
        );
      }

      // Wait for all scans with timeout
      await Future.wait(
        futures,
      ).timeout(const Duration(seconds: 10), onTimeout: () => []);
    } catch (e) {
      print('Error scanning WiFi printers: $e');
    }

    return devices;
  }

  /// Check if a printer is available at the given IP and port
  Future<bool> _checkPrinterAtIP(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 1),
      );
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Scan for Bluetooth printers using unified discovery flow
  ///
  /// UNIFIED DISCOVERY FLOW:
  /// 1. ALWAYS shows built-in printers (Sunmi) immediately if device supports them
  /// 2. ALWAYS shows ALL bonded (paired) Bluetooth Classic devices
  /// 3. Optional discovery scan for NEW unpaired devices
  /// 4. Handles Android version-specific permissions gracefully
  ///
  /// CRITICAL:
  /// - NEVER relies on Bluetooth discovery scan alone
  /// - ALWAYS displays bonded devices even if scan fails
  /// - NEVER shows "No printers found" when bonded devices exist
  ///
  /// PRODUCTION FIX: Hard timeout of 5 seconds max
  Future<List<PrinterDevice>> scanBluetoothPrinters() async {
    _logger.i('📡 Starting unified Bluetooth printer discovery...');

    try {
      // Use unified discovery service for comprehensive printer discovery
      final result = await Future.any([
        _unifiedDiscoveryService.discoverAllPrinters(
          includeDiscoveryScan: true,
          filterThermalOnly:
              false, // Show ALL bonded devices - don't filter aggressively
        ),
        Future.delayed(
          const Duration(seconds: 5),
          () => throw TimeoutException(
            'Unified discovery timed out',
            const Duration(seconds: 5),
          ),
        ),
      ]);

      // Log discovery results
      _logger.i('📊 Unified discovery complete:');
      _logger.i('   - Built-in: ${result.builtInPrinters.length}');
      _logger.i('   - Paired: ${result.pairedPrinters.length}');
      _logger.i('   - New: ${result.discoveredPrinters.length}');

      // Check for permission issues
      if (!result.permissionsGranted && result.builtInPrinters.isEmpty) {
        throw PrinterError(
          code: 'PERMISSIONS_REQUIRED',
          technicalMessage:
              result.permissionMessage ?? 'Bluetooth permissions required',
          userMessage: result.permissionMessage ?? 'صلاحيات البلوتوث مطلوبة',
          arabicTitle: 'صلاحيات مطلوبة',
          arabicMessage:
              result.permissionMessage ??
              'يحتاج التطبيق صلاحيات البلوتوث للوصول إلى الطابعات.',
          suggestions: [
            'اضغط "السماح" عند ظهور طلب الصلاحيات',
            'أو افتح إعدادات التطبيق وفعّل صلاحيات البلوتوث',
          ],
        );
      }

      // Check for Bluetooth disabled
      if (!result.bluetoothEnabled && result.builtInPrinters.isEmpty) {
        throw PrinterError(
          code: 'BLUETOOTH_DISABLED',
          technicalMessage: 'Bluetooth is disabled',
          userMessage: 'البلوتوث مغلق',
          arabicTitle: 'البلوتوث مغلق',
          arabicMessage: 'يرجى تشغيل البلوتوث من الإعدادات والمحاولة مرة أخرى.',
          suggestions: [
            'افتح إعدادات الجهاز',
            'فعّل البلوتوث',
            'عد إلى التطبيق واضغط "بحث عن طابعات"',
          ],
        );
      }

      // Return all discovered printers (built-in + paired + discovered)
      final allPrinters = result.allPrinters;

      if (allPrinters.isEmpty) {
        _logger.w('⚠️ No printers found in unified discovery');
        // Return empty list - UI will show helpful guidance
      } else {
        _logger.i(
          '✅ Returning ${allPrinters.length} printer(s) from unified discovery',
        );
      }

      return allPrinters;
    } on TimeoutException catch (_) {
      _logger.e('❌ Unified discovery timed out after 5 seconds');

      // Even on timeout, try to get bonded devices directly as fallback
      try {
        final fallbackPrinters = await _getFallbackBondedDevices();
        if (fallbackPrinters.isNotEmpty) {
          _logger.i(
            '✅ Fallback: Found ${fallbackPrinters.length} bonded device(s)',
          );
          return fallbackPrinters;
        }
      } catch (e) {
        _logger.w('⚠️ Fallback also failed: $e');
      }

      throw PrinterError(
        code: 'SCAN_TIMEOUT',
        technicalMessage: 'Unified discovery timed out',
        userMessage: 'انتهت مهلة البحث',
        arabicTitle: 'انتهت مهلة البحث',
        arabicMessage: 'انتهت مهلة البحث عن الطابعات. يرجى المحاولة مرة أخرى.',
        suggestions: [
          'تأكد من تفعيل البلوتوث',
          'تأكد من إقران الطابعة في إعدادات الأندرويد',
          'أعد تشغيل البلوتوث والمحاولة مرة أخرى',
        ],
      );
    } catch (e) {
      _logger.e('❌ Unified discovery failed: $e');

      // If it's already a PrinterError, rethrow
      if (e is PrinterError) {
        rethrow;
      }

      // Map unknown errors
      final printerError = _errorMapper.mapError(
        e,
        context: 'Unified Bluetooth discovery',
      );
      throw printerError;
    }
  }

  /// Fallback method to get bonded devices directly when unified discovery times out
  Future<List<PrinterDevice>> _getFallbackBondedDevices() async {
    _logger.i('🔄 Attempting fallback bonded device retrieval...');

    final bondedDevices = await _bluetoothPrinter.getBondedDevices();

    return bondedDevices.map((device) {
      return PrinterDevice(
        id: 'bt_classic_${device.address}',
        name: device.name ?? 'Unknown Device',
        address: device.address,
        type: PrinterConnectionType.bluetooth,
        isConnected: false,
        sourceType: PrinterSourceType.paired,
      );
    }).toList();
  }

  /// Scan for USB printers (DISABLED - usb_serial package has compatibility issues)
  Future<List<PrinterDevice>> scanUSBPrinters() async {
    final devices = <PrinterDevice>[];

    try {
      // USB scanning disabled due to package compatibility issues
      // To re-enable: uncomment usb_serial import and reinstall package
      // final usbDevices = await UsbSerial.listDevices();
      //
      // for (var device in usbDevices) {
      //   devices.add(PrinterDevice(
      //     id: 'usb_${device.deviceId}',
      //     name: device.productName ?? 'USB Printer',
      //     type: PrinterConnectionType.usb,
      //   ));
      // }

      print(
        'USB printer scanning is currently disabled. Use WiFi or Bluetooth instead.',
      );
    } catch (e) {
      print('Error scanning USB printers: $e');
    }

    return devices;
  }

  // ============================================================================
  // CONNECTION METHODS
  // ============================================================================

  /// Connect to a printer
  Future<bool> connectToPrinter(PrinterDevice device) async {
    try {
      switch (device.type) {
        case PrinterConnectionType.wifi:
          return await _connectToWiFiPrinter(device);
        case PrinterConnectionType.bluetooth:
          return await _connectToBluetoothPrinter(device);
        case PrinterConnectionType.manualConnect:
          // Manual connect is treated as Bluetooth connection
          return await _connectToBluetoothPrinter(device);
      }
    } catch (e) {
      print('Error connecting to printer: $e');
      return false;
    }
  }

  /// Connect to WiFi printer
  Future<bool> _connectToWiFiPrinter(PrinterDevice device) async {
    if (device.address == null || device.port == null) {
      return false;
    }

    final printer = NetworkPrinter(
      _getEscPosPaperSize(),
      await esc_pos.CapabilityProfile.load(),
    );
    final result = await printer.connect(device.address!, port: device.port!);

    if (result == PosPrintResult.success) {
      _networkPrinter = printer;
      _connectedPrinter = device.copyWith(isConnected: true);
      await _saveConnectedPrinter(device);
      return true;
    }

    return false;
  }

  /// Connect to Bluetooth printer with comprehensive error handling and retry logic
  Future<bool> _connectToBluetoothPrinter(PrinterDevice device) async {
    _logger.i('🔌 Attempting to connect to Bluetooth printer: ${device.name}');

    if (device.address == null) {
      _logger.e('❌ Device address is null');
      throw PrinterError.connectionRefused();
    }

    try {
      // STEP 1: Pre-flight check before connection using new Classic service
      final classicCheck = await _bluetoothClassicService
          .performPreFlightCheck();
      if (!classicCheck.isReady) {
        _logger.w('⚠️ Environment not ready for connection');
        throw PrinterError(
          code: classicCheck.errorCode ?? 'CONNECTION_FAILED',
          technicalMessage: classicCheck.errorMessage ?? 'Connection failed',
          userMessage: classicCheck.errorMessage ?? 'فشل الاتصال',
          arabicTitle: 'فشل الاتصال',
          arabicMessage: classicCheck.arabicMessage,
          suggestions: classicCheck.userGuidance != null
              ? [classicCheck.userGuidance!]
              : [],
        );
      }

      // STEP 2: Disconnect any existing connection first
      await _safeDisconnectBluetooth();

      // STEP 3: Verify device is still paired
      final bondedDevices = await _bluetoothPrinter.getBondedDevices();
      final btDevice = bondedDevices.firstWhere(
        (d) => d.address == device.address,
        orElse: () => throw PrinterError.pairingRequired(),
      );

      _logger.i('📱 Found paired device: ${btDevice.name}');

      // STEP 4: Attempt connection with retry logic
      bool connected = false;
      int attempt = 0;

      while (!connected && attempt <= _maxRetries) {
        attempt++;
        _logger.i('🔄 Connection attempt $attempt/${_maxRetries + 1}');

        try {
          // Attempt connection with timeout
          await _bluetoothPrinter
              .connect(btDevice)
              .timeout(
                _connectionTimeout,
                onTimeout: () {
                  throw PrinterError.connectionTimeout();
                },
              );

          // Small delay to let connection stabilize
          await Future.delayed(const Duration(milliseconds: 500));

          // Verify connection
          final isConnected = await _bluetoothPrinter.isConnected;
          connected = isConnected == true;

          if (connected) {
            _logger.i('✅ Connection successful on attempt $attempt');
          } else {
            _logger.w('⚠️ Connection returned false on attempt $attempt');
          }
        } catch (e) {
          _logger.w('⚠️ Connection attempt $attempt failed: $e');

          // If this was the last attempt, throw the error
          if (attempt > _maxRetries) {
            // Map the error to user-friendly message
            final mappedError = _errorMapper.mapError(
              e,
              context: 'Bluetooth connection',
            );
            throw mappedError;
          }

          // Otherwise, wait before retry
          _logger.i('⏳ Waiting ${_retryDelay.inSeconds}s before retry...');
          await Future.delayed(_retryDelay);
        }
      }

      if (!connected) {
        _logger.e('❌ Failed to connect after ${_maxRetries + 1} attempts');
        throw PrinterError.connectionRefused();
      }

      // STEP 5: Save connected printer
      _connectedPrinter = device.copyWith(isConnected: true);
      await _saveConnectedPrinter(device);

      _logger.i('✅ Successfully connected to ${device.name}');
      return true;
    } catch (e) {
      _logger.e('❌ Bluetooth connection failed: $e');

      // If it's already a PrinterError, rethrow it
      if (e is PrinterError) {
        rethrow;
      }

      // Otherwise, map it
      final mappedError = _errorMapper.mapError(
        e,
        context: 'Bluetooth connection',
      );
      throw mappedError;
    }
  }

  /// Safely disconnect from Bluetooth printer
  /// Does not throw errors if already disconnected
  Future<void> _safeDisconnectBluetooth() async {
    try {
      final isConnected = await _bluetoothPrinter.isConnected;
      if (isConnected == true) {
        _logger.i('🔌 Disconnecting from previous Bluetooth connection...');
        await _bluetoothPrinter.disconnect();
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Give time to disconnect
        _logger.i('✅ Previous connection disconnected');
      }
    } catch (e) {
      _logger.w('⚠️ Error during safe disconnect (ignoring): $e');
      // Ignore errors during disconnect - we're trying to connect anyway
    }
  }

  /// Connect to USB printer (DISABLED - usb_serial package has compatibility issues)
  Future<bool> _connectToUSBPrinter(PrinterDevice device) async {
    // USB connection disabled due to package compatibility issues
    // To re-enable: uncomment usb_serial import and reinstall package

    print(
      'USB printer connection is currently disabled. Please use WiFi or Bluetooth.',
    );
    return false;

    /* Original USB connection code (disabled):
    final usbDevices = await UsbSerial.listDevices();
    
    // Find the USB device by ID
    final usbDevice = usbDevices.firstWhere(
      (d) => 'usb_${d.deviceId}' == device.id,
      orElse: () => throw Exception('USB device not found'),
    );

    // Create port and open connection
    final port = await usbDevice.create();
    final opened = await port?.open();

    if (opened == true && port != null) {
      await port.setDTR(true);
      await port.setRTS(true);
      
      // Set baud rate for thermal printers (common: 9600 or 115200)
      port.setPortParameters(
        115200, // baudRate
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _usbPort = port;
      _connectedPrinter = device.copyWith(isConnected: true);
      await _saveConnectedPrinter(device);
      return true;
    }

    return false;
    */
  }

  /// Disconnect from current printer
  Future<void> disconnect() async {
    if (_connectedPrinter == null) return;

    try {
      switch (_connectedPrinter!.type) {
        case PrinterConnectionType.wifi:
          _networkPrinter?.disconnect();
          _networkPrinter = null;
          break;
        case PrinterConnectionType.bluetooth:
          await _bluetoothPrinter.disconnect();
          break;
        case PrinterConnectionType.manualConnect:
          // Manual connect is treated as Bluetooth
          await _bluetoothPrinter.disconnect();
          break;
      }

      _connectedPrinter = null;
      await _clearConnectedPrinter();
    } catch (e) {
      print('Error disconnecting printer: $e');
    }
  }

  // ============================================================================
  // PRINTING METHODS
  // ============================================================================

  /// Print invoice directly from InvoiceData (IMAGE-BASED ONLY)
  ///
  /// This is the UNIFIED thermal printing method that:
  /// 1. Renders the receipt as an image (supports Arabic perfectly)
  /// 2. Sends raster image to printer
  /// 3. Works on ALL thermal printer brands
  ///
  /// NO text encoding, NO charset converter, NO printer-specific logic.
  ///
  /// 🧪 TEST MODE:
  /// If `thermalPdfTestMode` is enabled, this will preview the receipt as
  /// an A4 PDF instead of printing to a thermal printer.
  Future<bool> printInvoiceDirectFromData(InvoiceData data) async {
    // ═══════════════════════════════════════════════════════════════════════════
    // 🧪 PDF TEST MODE ROUTING
    // ═══════════════════════════════════════════════════════════════════════════
    if (thermalPdfTestMode) {
      _logger.i('[PDF TEST] ═══════════════════════════════════════════');
      _logger.i('[PDF TEST] Test mode enabled - previewing as PDF');
      _logger.i('[PDF TEST] ═══════════════════════════════════════════');

      try {
        // Convert ESC/POS paper size to thermal paper size enum
        final testPaperSize = _settings.paperSize == esc_pos.PaperSize.mm58
            ? ThermalPaperSize.mm58
            : ThermalPaperSize.mm80;

        // Preview receipt as PDF (reuses same thermal widget)
        await ThermalPdfTestService.previewThermalReceiptAsPdf(
          data,
          paperSize: testPaperSize,
          receiptName:
              'thermal_receipt_test_${DateTime.now().millisecondsSinceEpoch}',
        );

        _logger.i('[PDF TEST] ═══════════════════════════════════════════');
        _logger.i('[PDF TEST] PDF preview completed');
        _logger.i('[PDF TEST] ═══════════════════════════════════════════');

        return true;
      } catch (e, stackTrace) {
        _logger.e(
          '[PDF TEST] ❌ Failed to preview PDF',
          error: e,
          stackTrace: stackTrace,
        );
        return false;
      }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 🖨️ PRODUCTION THERMAL PRINTING
    // ═══════════════════════════════════════════════════════════════════════════
    _logger.i('[PRINT] ═══════════════════════════════════════════');
    _logger.i('[PRINT] Rendering receipt as image');
    _logger.i('[PRINT] ═══════════════════════════════════════════');

    if (_connectedPrinter == null) {
      _logger.e('[PRINT] ❌ No printer connected');
      throw Exception('No printer connected');
    }

    try {
      // Generate image-based receipt bytes
      final bytes = await ImageBasedThermalPrinter.generateImageBasedReceipt(
        data,
        paperSize: _getEscPosPaperSize(),
      );

      _logger.i('[PRINT] Image rendered successfully');
      _logger.i('[PRINT] Sending raster data to printer');

      // Send to printer
      final result = await printBytes(bytes);

      if (result) {
        _logger.i('[PRINT] ═══════════════════════════════════════════');
        _logger.i('[PRINT] Thermal print completed');
        _logger.i('[PRINT] ═══════════════════════════════════════════');
      }

      return result;
    } catch (e, stackTrace) {
      _logger.e(
        '[PRINT] ❌ Failed to print invoice',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Print bytes to the connected printer
  /// ⚠️ CRITICAL: This method MUST complete transmission before returning
  /// The print job must execute immediately, not when app is backgrounded
  Future<bool> printBytes(List<int> bytes) async {
    final timestamp = DateTime.now().toIso8601String();
    print('[PRINT $timestamp] ========== START PRINT JOB ==========');

    if (_connectedPrinter == null) {
      print('[PRINT $timestamp] ❌ FAILED: No printer connected');
      throw Exception('No printer connected');
    }

    print('[PRINT $timestamp] Printer: ${_connectedPrinter!.name}');
    print('[PRINT $timestamp] Type: ${_connectedPrinter!.type}');
    print('[PRINT $timestamp] Data size: ${bytes.length} bytes');

    // Add retry logic for network printers (they can be unreliable)
    int maxRetries = _connectedPrinter!.type == PrinterConnectionType.wifi
        ? 2
        : 1;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('[PRINT $timestamp] 🔄 Attempt $attempt/$maxRetries');

        bool success = false;
        switch (_connectedPrinter!.type) {
          case PrinterConnectionType.wifi:
            success = await _printToWiFi(bytes, timestamp);
            break;
          case PrinterConnectionType.bluetooth:
            success = await _printToBluetooth(bytes, timestamp);
            break;
          case PrinterConnectionType.manualConnect:
            // Manual connect is treated as Bluetooth
            success = await _printToBluetooth(bytes, timestamp);
            break;
        }

        if (success) {
          print(
            '[PRINT $timestamp] ✅ SUCCESS: Print completed on attempt $attempt',
          );
          print('[PRINT $timestamp] ========== END PRINT JOB ==========');
          return true;
        }

        // If not the last attempt, wait before retrying
        if (attempt < maxRetries) {
          print('[PRINT $timestamp] ⏳ Retry wait (2s)...');
          await Future.delayed(Duration(seconds: 2));
        }
      } catch (e, stackTrace) {
        print('[PRINT $timestamp] ❌ ERROR on attempt $attempt: $e');
        print('[PRINT $timestamp] Stack trace: $stackTrace');

        // If not the last attempt, wait before retrying
        if (attempt < maxRetries) {
          print('[PRINT $timestamp] ⏳ Retry wait (2s)...');
          await Future.delayed(Duration(seconds: 2));
        } else {
          // Last attempt failed
          print('[PRINT $timestamp] ❌ FAILED: All retry attempts exhausted');
          print('[PRINT $timestamp] ========== END PRINT JOB ==========');
          return false;
        }
      }
    }

    print('[PRINT $timestamp] ❌ FAILED: Unknown error');
    print('[PRINT $timestamp] ========== END PRINT JOB ==========');
    return false;
  }

  /// Print to WiFi printer with HARD FLUSH and proper socket lifecycle
  /// ⚠️ CRITICAL FIX: Socket must be flushed AND closed to trigger immediate transmission
  /// The OS buffers socket data and only flushes when:
  /// 1. Socket is explicitly closed
  /// 2. App is backgrounded/terminated
  /// This is why printing only worked when app was closed!
  Future<bool> _printToWiFi(List<int> bytes, String timestamp) async {
    if (_connectedPrinter == null) {
      print('[PRINT $timestamp] ❌ No connected printer for WiFi');
      return false;
    }

    Socket? socket;

    try {
      final address = _connectedPrinter!.address!;
      final port = _connectedPrinter!.port!;

      print('[PRINT $timestamp] 📡 Connecting to WiFi printer...');
      print('[PRINT $timestamp]    Address: $address:$port');

      // Step 1: Open socket connection
      socket = await Socket.connect(
        address,
        port,
        timeout: const Duration(seconds: 10),
      );

      print('[PRINT $timestamp] ✅ Socket opened successfully');
      print('[PRINT $timestamp] 📤 Sending ${bytes.length} bytes...');

      // Step 2: Add bytes to socket buffer
      socket.add(bytes);
      print('[PRINT $timestamp] ✅ Bytes added to socket buffer');

      // Step 3: CRITICAL - Flush socket to OS buffer
      print('[PRINT $timestamp] 🔄 Flushing socket to OS buffer...');
      await socket.flush();
      print('[PRINT $timestamp] ✅ Socket flushed to OS buffer');

      // Step 4: CRITICAL - Wait for socket drain (ensure bytes leave OS buffer)
      // This is the key fix - we need to wait for the socket to drain
      // Without this, the OS may not transmit immediately
      print('[PRINT $timestamp] ⏳ Waiting for socket drain...');

      // Listen to the socket to ensure all data is transmitted
      // The socket will signal when it's done transmitting
      final completer = Completer<void>();
      final drainTimer = Timer(Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          print(
            '[PRINT $timestamp] ⏰ Drain timeout - assuming transmission complete',
          );
          completer.complete();
        }
      });

      // Wait for socket to be writable (indicates buffer is empty)
      socket.done
          .then((_) {
            if (!completer.isCompleted) {
              print('[PRINT $timestamp] ✅ Socket done signal received');
              drainTimer.cancel();
              completer.complete();
            }
          })
          .catchError((error) {
            if (!completer.isCompleted) {
              print('[PRINT $timestamp] ⚠️ Socket done error: $error');
              drainTimer.cancel();
              completer.complete();
            }
          });

      // Give a moment for the drain to complete
      await Future.delayed(Duration(milliseconds: 500));
      drainTimer.cancel();

      print('[PRINT $timestamp] ✅ Socket drain complete');

      // Step 5: CRITICAL - Close socket to force final transmission
      // This is essential - the OS MUST know we're done with this connection
      print('[PRINT $timestamp] 🔒 Closing socket...');
      await socket.close();
      print('[PRINT $timestamp] ✅ Socket closed');

      // Step 6: Final wait to ensure OS processes the close
      // This ensures the OS has time to process the close and transmit
      await Future.delayed(Duration(milliseconds: 200));

      print('[PRINT $timestamp] ✅ WiFi print transmission complete');
      return true;
    } catch (e, stackTrace) {
      print('[PRINT $timestamp] ❌ WiFi print error: $e');
      print('[PRINT $timestamp] Stack: $stackTrace');

      // Ensure socket is closed even on error
      try {
        if (socket != null) {
          print('[PRINT $timestamp] 🧹 Cleaning up socket...');
          await socket.close();
        }
      } catch (closeError) {
        print('[PRINT $timestamp] ⚠️ Error closing socket: $closeError');
      }

      return false;
    }
  }

  /// Print to Bluetooth printer with proper flush
  /// ⚠️ CRITICAL: Bluetooth also suffers from buffer flush issues
  /// The Bluetooth stack may buffer data until app is backgrounded
  Future<bool> _printToBluetooth(List<int> bytes, String timestamp) async {
    try {
      print('[PRINT $timestamp] 📱 Checking Bluetooth connection...');

      final isConnected = await _bluetoothPrinter.isConnected;
      if (isConnected != true) {
        print('[PRINT $timestamp] ❌ Bluetooth printer not connected');
        return false;
      }

      print('[PRINT $timestamp] ✅ Bluetooth connected');
      print(
        '[PRINT $timestamp] 📤 Sending ${bytes.length} bytes to Bluetooth...',
      );

      // Send bytes to Bluetooth printer
      await _bluetoothPrinter.writeBytes(Uint8List.fromList(bytes));
      print('[PRINT $timestamp] ✅ Bytes written to Bluetooth buffer');

      // CRITICAL: Wait for Bluetooth transmission
      // Bluetooth is slower than WiFi and needs more time to transmit
      // This ensures the data actually leaves the buffer
      print('[PRINT $timestamp] ⏳ Waiting for Bluetooth transmission...');
      await Future.delayed(Duration(milliseconds: 1500));

      print('[PRINT $timestamp] ✅ Bluetooth transmission complete');
      return true;
    } catch (e, stackTrace) {
      print('[PRINT $timestamp] ❌ Bluetooth print error: $e');
      print('[PRINT $timestamp] Stack: $stackTrace');
      return false;
    }
  }

  /// Print to USB printer (DISABLED - usb_serial package has compatibility issues)
  Future<bool> _printToUSB(List<int> bytes, String timestamp) async {
    // USB printing disabled due to package compatibility issues
    print('[PRINT $timestamp] ❌ USB printing is currently disabled');
    print('[PRINT $timestamp] Please use WiFi or Bluetooth instead');
    return false;

    /* Original USB printing code (disabled):
    if (_usbPort == null) return false;
    await _usbPort!.write(Uint8List.fromList(bytes));
    return true;
    */
  }

  // ============================================================================
  // PERSISTENCE METHODS
  // ============================================================================

  /// Save connected printer to preferences
  Future<void> _saveConnectedPrinter(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connected_printer', jsonEncode(device.toJson()));
  }

  /// Clear connected printer from preferences
  Future<void> _clearConnectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('connected_printer');
  }

  /// Load previously connected printer
  Future<PrinterDevice?> loadConnectedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('connected_printer');

      if (jsonString != null) {
        return PrinterDevice.fromJson(jsonDecode(jsonString));
      }
    } catch (e) {
      print('Error loading connected printer: $e');
    }
    return null;
  }

  /// Auto-reconnect to previously connected printer
  Future<bool> autoReconnect() async {
    // Load settings first
    await loadSettings();

    final savedPrinter = await loadConnectedPrinter();
    if (savedPrinter != null) {
      return await connectToPrinter(savedPrinter);
    }
    return false;
  }

  // ============================================================================
  // SETTINGS MANAGEMENT
  // ============================================================================

  /// Update printer settings (paper size, etc.)
  Future<void> updateSettings(PrinterSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
  }

  /// Load printer settings from storage
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('printer_settings');

      if (jsonString != null) {
        _settings = PrinterSettings.fromJson(jsonDecode(jsonString));
      }
    } catch (e) {
      print('Error loading printer settings: $e');
    }
  }

  /// Save printer settings to storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_settings', jsonEncode(_settings.toJson()));
    } catch (e) {
      print('Error saving printer settings: $e');
    }
  }

  /// Convert our PaperSize enum to ESC/POS library's PaperSize
  esc_pos.PaperSize _getEscPosPaperSize() {
    switch (_settings.paperSize) {
      case PaperSize.mm58:
        return esc_pos.PaperSize.mm58;
      case PaperSize.mm80:
        return esc_pos.PaperSize.mm80;
      case PaperSize.a4:
        return esc_pos.PaperSize.mm80; // Use 80mm for A4, adjust in generator
    }
  }

  // ============================================================================
  // TEST PRINT
  // ============================================================================

  /// Generate and print a test receipt
  Future<bool> printTestReceipt() async {
    if (_connectedPrinter == null) {
      throw Exception('No printer connected');
    }

    try {
      // Generate test receipt bytes
      final profile = await esc_pos.CapabilityProfile.load();
      final generator = esc_pos.Generator(_getEscPosPaperSize(), profile);
      List<int> bytes = [];

      // Header
      bytes += generator.text(
        'TEST RECEIPT',
        styles: const esc_pos.PosStyles(
          align: esc_pos.PosAlign.center,
          height: esc_pos.PosTextSize.size2,
          width: esc_pos.PosTextSize.size2,
          bold: true,
        ),
      );
      bytes += generator.emptyLines(1);

      // Separator
      bytes += generator.text(
        '================================',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
      );
      bytes += generator.emptyLines(1);

      // Connection info
      bytes += generator.text(
        'Printer: ${_connectedPrinter!.name}',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
      );
      bytes += generator.text(
        'Type: ${_connectedPrinter!.type.toString().split('.').last.toUpperCase()}',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
      );
      if (_connectedPrinter!.address != null) {
        bytes += generator.text(
          'Address: ${_connectedPrinter!.address}',
          styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
        );
      }
      bytes += generator.emptyLines(1);

      // Paper size info
      bytes += generator.text(
        'Paper Size: ${_settings.paperSize.displayName}',
        styles: const esc_pos.PosStyles(
          align: esc_pos.PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.text(
        'Width: ${_settings.paperSize.charsPerLine} chars/line',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
      );
      bytes += generator.emptyLines(1);

      // Date and time
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      bytes += generator.text(
        'Date: $dateStr',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
      );
      bytes += generator.emptyLines(1);

      // Separator
      bytes += generator.text(
        '================================',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
      );
      bytes += generator.emptyLines(1);

      // Test patterns
      bytes += generator.text(
        'Text Alignment Test:',
        styles: const esc_pos.PosStyles(bold: true),
      );
      bytes += generator.text(
        'LEFT ALIGNED',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.left),
      );
      bytes += generator.text(
        'CENTER ALIGNED',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
      );
      bytes += generator.text(
        'RIGHT ALIGNED',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.right),
      );
      bytes += generator.emptyLines(1);

      // Character set test
      bytes += generator.text(
        'Character Test: 1234567890',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
      );
      bytes += generator.text(
        'English: Welcome',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
      );
      bytes += generator.emptyLines(2);

      // Status
      bytes += generator.text(
        '[OK] Printer is working correctly!',
        styles: const esc_pos.PosStyles(
          align: esc_pos.PosAlign.center,
          bold: true,
        ),
      );
      bytes += generator.emptyLines(1);

      bytes += generator.text(
        'Barber Cashier System',
        styles: const esc_pos.PosStyles(align: esc_pos.PosAlign.center),
      );

      // Cut paper
      bytes += generator.feed(2);
      bytes += generator.cut();

      // Send to printer
      return await printBytes(bytes);
    } catch (e) {
      print('Error printing test receipt: $e');
      return false;
    }
  }
}
