import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../screens/casher/models/printer_device.dart';
import '../../screens/casher/services/printer_service.dart';
import '../../services/permission_service.dart';
import '../../services/printer_error_mapper.dart' as error_mapper;
import '../../models/printer_settings.dart';
import 'printer_state.dart';

/// Cubit for managing printer operations
class PrinterCubit extends Cubit<PrinterState> {
  final PrinterService _printerService;
  final PermissionService _permissionService;
  final error_mapper.PrinterErrorMapper _errorMapper =
      error_mapper.PrinterErrorMapper();

  PrinterCubit({
    PrinterService? printerService,
    PermissionService? permissionService,
  }) : _printerService = printerService ?? PrinterService(),
       _permissionService = permissionService ?? PermissionService(),
       super(const PrinterInitial());

  /// Initialize and auto-reconnect to previously connected printer
  Future<void> initialize() async {
    try {
      final success = await _printerService.autoReconnect();
      if (success && _printerService.connectedPrinter != null) {
        emit(PrinterConnected(_printerService.connectedPrinter!));
      }
    } catch (e) {
      final errorMsg = _getErrorMessage(e);
      emit(PrinterError(errorMsg));
    }
  }

  /// Request Bluetooth permissions
  /// Returns true if permissions are granted
  Future<PermissionResult> requestBluetoothPermissions() async {
    return await _permissionService.requestBluetoothPermissions();
  }

  /// Check if Bluetooth permissions are granted
  Future<bool> checkBluetoothPermissions() async {
    return await _permissionService.checkBluetoothPermissions();
  }

  /// Scan for printers based on connection type
  ///
  /// PRODUCTION FIX: Hard timeout of 5 seconds to prevent infinite loading
  /// - Bluetooth Classic retrieval should be instant (< 100ms)
  /// - WiFi/USB scanning may take longer
  /// - If timeout occurs, user gets clear error message
  /// - Loading state ALWAYS resolves to success or error
  Future<void> scanPrinters(PrinterConnectionType type) async {
    emit(PrinterScanning(type));

    try {
      // CRITICAL FIX: Wrap entire scan operation in timeout
      // Bluetooth Classic: Should complete in < 1 second
      // WiFi/USB: May take up to 5 seconds
      final devices = await Future.any([
        _performScan(type),
        Future.delayed(
          const Duration(seconds: 5),
          () => throw TimeoutException(
            'Printer scan timed out after 5 seconds',
            const Duration(seconds: 5),
          ),
        ),
      ]);

      // SUCCESS: Always emit result, even if empty
      emit(PrintersFound(devices, type));
    } on TimeoutException catch (_) {
      // TIMEOUT: Show user-friendly message
      final errorMsg = type == PrinterConnectionType.bluetooth
          ? 'انتهت مهلة البحث عن الطابعات. تأكد من تفعيل البلوتوث وإقران الطابعة في إعدادات الأندرويد.'
          : 'انتهت مهلة البحث عن الطابعات. تأكد من تشغيل الطابعة واتصالها بالشبكة.';

      emit(PrinterError(errorMsg));
    } catch (e) {
      // ERROR: Always emit error state
      final errorMsg = _getErrorMessage(e);
      emit(PrinterError(errorMsg));
    }
  }

  /// Internal scan method extracted for timeout wrapping
  Future<List<PrinterDevice>> _performScan(PrinterConnectionType type) async {
    switch (type) {
      case PrinterConnectionType.wifi:
        return await _printerService.scanWiFiPrinters();
      case PrinterConnectionType.bluetooth:
        // The service now handles pre-flight checks internally
        return await _printerService.scanBluetoothPrinters();
      case PrinterConnectionType.manualConnect:
        // Manual connect doesn't scan, returns empty list
        return [];
    }
  }

  /// Connect to a specific printer
  Future<void> connectToPrinter(PrinterDevice device) async {
    emit(PrinterConnecting(device));

    try {
      final success = await _printerService.connectToPrinter(device);

      if (success) {
        emit(PrinterConnected(device));
      } else {
        emit(const PrinterError('فشل الاتصال بالطابعة'));
      }
    } catch (e) {
      final errorMsg = _getErrorMessage(e);
      emit(PrinterError(errorMsg));
    }
  }

  /// Disconnect from current printer
  Future<void> disconnect() async {
    try {
      await _printerService.disconnect();
      emit(const PrinterDisconnected());
    } catch (e) {
      emit(PrinterError('Disconnect error: $e'));
    }
  }

  /// Print bytes to connected printer
  Future<void> printBytes(List<int> bytes) async {
    if (_printerService.connectedPrinter == null) {
      emit(const PrinterError('No printer connected'));
      return;
    }

    emit(const PrinterPrinting());

    try {
      final success = await _printerService.printBytes(bytes);

      if (success) {
        emit(const PrinterPrintSuccess());
        // Return to connected state
        if (_printerService.connectedPrinter != null) {
          emit(PrinterConnected(_printerService.connectedPrinter!));
        }
      } else {
        emit(const PrinterError('Failed to print'));
      }
    } catch (e) {
      emit(PrinterError('Print error: $e'));
    }
  }

  /// Get currently connected printer
  PrinterDevice? get connectedPrinter => _printerService.connectedPrinter;

  /// Check if a printer is connected
  bool get isConnected => _printerService.connectedPrinter != null;

  /// Get current printer settings
  PrinterSettings get settings => _printerService.settings;

  /// Update printer settings (paper size, etc.)
  Future<void> updateSettings(PrinterSettings newSettings) async {
    try {
      await _printerService.updateSettings(newSettings);

      // Emit current state again to trigger UI update
      if (_printerService.connectedPrinter != null) {
        emit(PrinterConnected(_printerService.connectedPrinter!));
      }
    } catch (e) {
      emit(PrinterError('Failed to update settings: $e'));
    }
  }

  /// Send a test print to verify printer functionality
  Future<void> testPrint() async {
    if (_printerService.connectedPrinter == null) {
      emit(const PrinterError('No printer connected'));
      return;
    }

    emit(const PrinterPrinting());

    try {
      final success = await _printerService.printTestReceipt();

      if (success) {
        emit(const PrinterPrintSuccess());
        // Return to connected state after 2 seconds
        await Future.delayed(const Duration(seconds: 2));
        if (_printerService.connectedPrinter != null) {
          emit(PrinterConnected(_printerService.connectedPrinter!));
        }
      } else {
        emit(const PrinterError('Test print failed'));
      }
    } catch (e) {
      emit(PrinterError('Test print error: $e'));
    }
  }

  /// Map any error to a user-friendly Arabic message
  String _getErrorMessage(dynamic error) {
    // If it's already a PrinterError from our error mapper, use its Arabic message
    if (error is error_mapper.PrinterError) {
      return error.arabicMessage;
    }

    // Otherwise, map it
    final mappedError = _errorMapper.mapError(error);
    return mappedError.arabicMessage;
  }
}
