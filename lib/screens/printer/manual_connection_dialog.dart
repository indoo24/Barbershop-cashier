import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/manual_printer_connection_service.dart';

/// Manual Printer Connection Dialog
///
/// Allows users to connect to a Bluetooth thermal printer by entering
/// its MAC address directly. This is the guaranteed fallback when
/// automatic discovery doesn't show the printer.
///
/// Features:
/// - MAC address validation with real-time feedback
/// - Flexible format support (colons, dashes, no separators)
/// - Optional printer name input
/// - Help text with instructions
/// - Error display with suggestions
class ManualConnectionDialog extends StatefulWidget {
  const ManualConnectionDialog({super.key});

  @override
  State<ManualConnectionDialog> createState() => _ManualConnectionDialogState();
}

class _ManualConnectionDialogState extends State<ManualConnectionDialog> {
  final _logger = Logger();
  final _macController = TextEditingController();
  final _nameController = TextEditingController();
  final _manualService = ManualPrinterConnectionService();

  bool _isConnecting = false;
  String? _errorMessage;
  List<String> _suggestions = [];
  bool _isValidFormat = false;

  @override
  void initState() {
    super.initState();
    _macController.addListener(_validateFormat);
  }

  void _validateFormat() {
    final input = _macController.text;
    if (input.isEmpty) {
      setState(() {
        _isValidFormat = false;
        _errorMessage = null;
      });
      return;
    }

    final normalized = _manualService.validateAndNormalizeMacAddress(input);

    setState(() {
      _isValidFormat = normalized != null;
      if (!_isValidFormat && input.length >= 6) {
        _errorMessage = 'صيغة عنوان MAC غير صحيحة';
      } else {
        _errorMessage = null;
      }
    });
  }

  Future<void> _connect() async {
    final macAddress = _macController.text.trim();
    final printerName = _nameController.text.trim().isEmpty
        ? 'Manual Printer'
        : _nameController.text.trim();

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _suggestions = [];
    });

    try {
      _logger.i('🔌 Attempting manual connection to $macAddress');

      final printer = await _manualService.connectByMacAddress(
        macAddress: macAddress,
        printerName: printerName,
      );

      _logger.i('✅ Manual connection successful: ${printer.name}');

      if (mounted) {
        // Return printer to caller
        Navigator.of(context).pop(printer);
      }
    } on ManualConnectionException catch (e) {
      _logger.e('❌ Manual connection failed: ${e.code}');

      setState(() {
        _errorMessage = e.arabicMessage;
        _suggestions = e.suggestions;
        _isConnecting = false;
      });
    } catch (e) {
      _logger.e('❌ Unexpected error during manual connection: $e');

      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع أثناء الاتصال';
        _suggestions = ['تحقق من عنوان MAC', 'تأكد من تشغيل الطابعة'];
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bluetooth_searching,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اتصال يدوي',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'أدخل عنوان MAC للطابعة',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // MAC Address Input
              TextField(
                controller: _macController,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  labelText: 'عنوان MAC',
                  hintText: 'AA:BB:CC:DD:EE:FF',
                  helperText: 'يمكن استخدام : أو - أو بدون فواصل',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.pin),
                  suffixIcon: _isValidFormat
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : _macController.text.length >= 6
                          ? const Icon(Icons.error, color: Colors.red)
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                enabled: !_isConnecting,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              // Printer Name Input (Optional)
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الطابعة (اختياري)',
                  hintText: 'مثال: طابعة المحل الرئيسية',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                enabled: !_isConnecting,
              ),
              const SizedBox(height: 20),

              // Help Section (Expandable)
              ExpansionTile(
                leading: Icon(Icons.help_outline, color: Colors.blue[700]),
                title: const Text(
                  'كيفية إيجاد عنوان MAC؟',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHelpItem(
                          '1. في إعدادات البلوتوث',
                          'افتح إعدادات البلوتوث > ابحث عن الطابعة المقترنة',
                        ),
                        _buildHelpItem(
                          '2. على الطابعة نفسها',
                          'ابحث عن ملصق على الطابعة يحتوي على العنوان',
                        ),
                        _buildHelpItem(
                          '3. طباعة صفحة اختبار',
                          'اطبع صفحة اختبار من الطابعة (غالباً عند الضغط المطول على زر التشغيل)',
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'أمثلة على الصيغ المقبولة:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._manualService
                            .getMacAddressExamples()
                            .take(3)
                            .map((example) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '• $example',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                )),
                      ],
                    ),
                  ),
                ],
              ),

              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'الحلول المقترحة:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._suggestions.map(
                          (suggestion) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ', style: TextStyle(color: Colors.red[900])),
                                Expanded(
                                  child: Text(
                                    suggestion,
                                    style: TextStyle(color: Colors.red[800]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isConnecting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (_isConnecting || !_isValidFormat)
                          ? null
                          : _connect,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isConnecting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.link, size: 20),
                                SizedBox(width: 8),
                                Text('اتصال'),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _macController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
