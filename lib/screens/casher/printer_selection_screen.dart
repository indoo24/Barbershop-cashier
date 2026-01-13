import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../cubits/printer/printer_cubit.dart';
import '../../cubits/printer/printer_state.dart';
import '../../services/permission_service.dart';
import '../../models/printer_settings.dart';
import 'models/printer_device.dart';
import 'package:toastification/toastification.dart';
import '../../helpers/validation_guard_mixin.dart';
import '../printer/manual_connection_dialog.dart';

/// Printer selection and management screen
class PrinterSelectionScreen extends StatefulWidget {
  const PrinterSelectionScreen({super.key});

  @override
  State<PrinterSelectionScreen> createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen>
    with SingleTickerProviderStateMixin, ValidationGuardMixin {
  late TabController _tabController;
  PrinterConnectionType _selectedType = PrinterConnectionType.wifi;
  PaperSize _selectedPaperSize = PaperSize.mm80;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedType = PrinterConnectionType.values[_tabController.index];
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize once
    if (!_isInitialized) {
      final cubit = context.read<PrinterCubit>();
      _selectedPaperSize = cubit.settings.paperSize;
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _scanPrinters() async {
    // Validate environment before scanning
    final isValid = await validateBeforePrinterOperation(
      operationName: 'scan for printers',
    );

    if (!isValid) return;

    // Proceed with scanning
    if (!mounted) return;
    context.read<PrinterCubit>().scanPrinters(_selectedType);
  }

  Future<void> _showManualConnectionDialog() async {
    final printer = await showDialog<PrinterDevice>(
      context: context,
      builder: (context) => const ManualConnectionDialog(),
    );

    if (printer != null && mounted) {
      // Connect to manually added printer
      context.read<PrinterCubit>().connectToPrinter(printer);
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('صلاحيات البلوتوث مطلوبة'),
        content: const Text(
          'تطبيق الصالون يحتاج صلاحيات البلوتوث للبحث عن الطابعات.\n\n'
          'الرجاء فتح الإعدادات ومنح الصلاحيات التالية:\n'
          '• Bluetooth Scan\n'
          '• Bluetooth Connect\n'
          '• Location',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  void _showBluetoothPairingGuidance() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.orange),
            SizedBox(width: 12),
            Text('لم يتم العثور على طابعات مقترنة'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لم يتم العثور على طابعات بلوتوث مقترنة مع هذا الجهاز.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'لإعداد طابعة بلوتوث:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildStep('1', 'شغّل الطابعة الحرارية'),
              _buildStep('2', 'افتح إعدادات الأندرويد'),
              _buildStep('3', 'انتقل إلى البلوتوث'),
              _buildStep('4', 'اضغط "البحث عن أجهزة جديدة"'),
              _buildStep('5', 'اختر طابعتك من القائمة'),
              _buildStep('6', 'أدخل رمز PIN (عادة: 0000 أو 1234)'),
              _buildStep('7', 'ارجع لهذا التطبيق واضغط "بحث عن طابعات"'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ملاحظة: الطابعات الحرارية تستخدم Bluetooth Classic، ليس BLE. يجب إقرانها في إعدادات النظام أولاً.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            icon: const Icon(Icons.settings_bluetooth),
            label: const Text('فتح إعدادات البلوتوث'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              icon,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _connectToPrinter(PrinterDevice device) {
    context.read<PrinterCubit>().connectToPrinter(device);
  }

  void _disconnect() {
    context.read<PrinterCubit>().disconnect();
  }

  Future<void> _updatePaperSize(PaperSize newSize) async {
    setState(() => _selectedPaperSize = newSize);

    final cubit = context.read<PrinterCubit>();
    final currentSettings = cubit.settings;

    await cubit.updateSettings(currentSettings.copyWith(paperSize: newSize));

    if (mounted) {
      toastification.show(
        context: context,
        title: Text('تم تحديث حجم الورق إلى ${newSize.displayName}'),
        type: ToastificationType.success,
        autoCloseDuration: const Duration(seconds: 2),
      );
    }
  }

  Widget _buildPaperSizeSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'حجم الورق',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: PaperSize.values.map((size) {
              final isSelected = _selectedPaperSize == size;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    elevation: isSelected ? 4 : 2,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _updatePaperSize(size),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.dividerColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.note,
                              color: isSelected
                                  ? Colors.white
                                  : theme.iconTheme.color,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              size.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${size.charsPerLine} حرف',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isSelected
                                    ? Colors.white70
                                    : theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'يُستخدم حجم الورق المحدد لتنسيق الإيصالات المطبوعة',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الطابعة'),
        centerTitle: true,
        actions: [
          BlocBuilder<PrinterCubit, PrinterState>(
            builder: (context, state) {
              if (state is PrinterConnected) {
                return IconButton(
                  icon: const Icon(Icons.link_off),
                  tooltip: 'قطع الاتصال',
                  onPressed: _disconnect,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<PrinterCubit, PrinterState>(
        listener: (context, state) {
          if (state is PrinterConnected) {
            toastification.show(
              context: context,
              title: Text('تم الاتصال بالطابعة: ${state.device.name}'),
              type: ToastificationType.success,
              autoCloseDuration: const Duration(seconds: 2),
            );
          } else if (state is PrinterError) {
            // Show detailed error message
            // Check if it's a critical error that needs a dialog
            final message = state.message;
            final isCriticalError =
                message.contains('مطلوبة') ||
                message.contains('مغلق') ||
                message.contains('غير مدعوم') ||
                message.contains('يجب') ||
                message.length > 100;

            if (isCriticalError) {
              // Show dialog for critical errors with detailed explanation
              toastification.show(
                context: context,
                title: Text(message),
                type: ToastificationType.error,
                autoCloseDuration: const Duration(seconds: 5),
                showProgressBar: true,
              );
            } else {
              // Show toast for simple errors
              toastification.show(
                context: context,
                title: Text(message),
                type: ToastificationType.error,
                autoCloseDuration: const Duration(seconds: 3),
              );
            }
          } else if (state is PrintersFound && state.devices.isEmpty) {
            // Show helpful message when no devices found
            if (state.type == PrinterConnectionType.bluetooth) {
              // Show comprehensive Bluetooth pairing guidance
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showBluetoothPairingGuidance();
              });
            } else {
              final typeArabic = state.type == PrinterConnectionType.wifi
                  ? 'شبكة'
                  : 'USB';

              toastification.show(
                context: context,
                title: Text('لم يتم العثور على طابعات $typeArabic'),
                description: const Text(
                  'تأكد من أن الطابعة مشغلة ومتصلة بالشبكة',
                ),
                type: ToastificationType.warning,
                autoCloseDuration: const Duration(seconds: 4),
              );
            }
          } else if (state is PrinterDisconnected) {
            toastification.show(
              context: context,
              title: const Text('تم قطع الاتصال بالطابعة'),
              type: ToastificationType.info,
              autoCloseDuration: const Duration(seconds: 2),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Paper Size Section
                _buildPaperSizeSection(Theme.of(context)),

                const Divider(height: 1),

                // Connected printer status
                if (state is PrinterConnected)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.green.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الطابعة المتصلة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              state.device.displayName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.link_off, color: Colors.red),
                        onPressed: _disconnect,
                      ),
                    ],
                  ),
                ),

              // Tabs for connection types
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.wifi), text: 'WiFi'),
                  Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
                  Tab(icon: Icon(Icons.edit), text: ' Manual'),
                ],
              ),

              // Scan button (for WiFi and Bluetooth tabs)
              if (_selectedType != PrinterConnectionType.manualConnect)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: state is PrinterScanning ? null : _scanPrinters,
                      icon: state is PrinterScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        state is PrinterScanning
                            ? 'جاري البحث...'
                            : 'بحث عن طابعات',
                      ),
                    ),
                  ),
                ),

              // Manual Connection Interface (for manual connect tab)
              if (_selectedType == PrinterConnectionType.manualConnect)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: state is PrinterConnecting ? null : _showManualConnectionDialog,
                      icon: const Icon(Icons.edit),
                      label: const Text('إدخال عنوان MAC للطابعة'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),

              // Printers list
              _buildPrintersList(state),
            ],
          ),
          );
        },
      ),
    );
  }

  Widget _buildPrintersList(PrinterState state) {
    // Special handling for manual connect tab
    if (_selectedType == PrinterConnectionType.manualConnect) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note, size: 80, color: Colors.blue[400]),
            const SizedBox(height: 24),
            const Text(
              'الاتصال اليدوي بالطابعة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'استخدم هذا الخيار إذا لم تظهر الطابعة في قائمة البلوتوث',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'متى تستخدم الاتصال اليدوي؟',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoItem('✓', 'الطابعة مقترنة لكن لا تظهر في قائمة البلوتوث'),
                    _buildInfoItem('✓', 'لديك عنوان MAC الخاص بالطابعة'),
                    _buildInfoItem('✓', 'تواجه مشاكل في اكتشاف الطابعة تلقائياً'),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.help_outline, color: Colors.orange, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'كيف تجد عنوان MAC؟',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoItem('1', 'ابحث عن ملصق على الطابعة'),
                    _buildInfoItem('2', 'اطبع صفحة اختبار من الطابعة'),
                    _buildInfoItem('3', 'راجع إعدادات البلوتوث في الأندرويد'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مثال على عنوان MAC:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'AA:BB:CC:DD:EE:FF',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: state is PrinterConnecting ? null : _showManualConnectionDialog,
                  icon: const Icon(Icons.edit),
                  label: const Text('إدخال عنوان MAC'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
      );
    }

    if (state is PrinterScanning) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري البحث عن الطابعات...'),
            SizedBox(height: 8),
            Text(
              'يتم البحث عن الطابعات المدمجة والمقترنة...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (state is PrintersFound) {
      if (state.devices.isEmpty) {
        // Show helpful guidance based on connection type
        if (state.type == PrinterConnectionType.bluetooth) {
          return _buildNoBluetoothPrintersView();
        }

        return Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.print_disabled, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'لم يتم العثور على طابعات',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'تأكد من أن الطابعة متصلة وقريبة',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        );
      }

      // Group printers by source type
      final builtInPrinters = state.devices
          .where((d) => d.sourceType == PrinterSourceType.builtIn)
          .toList();
      final pairedPrinters = state.devices
          .where((d) => d.sourceType == PrinterSourceType.paired)
          .toList();
      final discoveredPrinters = state.devices
          .where((d) => d.sourceType == PrinterSourceType.discovered)
          .toList();
      final unknownPrinters = state.devices
          .where((d) => d.sourceType == PrinterSourceType.unknown)
          .toList();

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Built-in printers section
            if (builtInPrinters.isNotEmpty) ...[
              _buildSectionHeader(
                'طابعات مدمجة',
                Icons.phone_android,
                Colors.green,
                'Built-in',
              ),
              ...builtInPrinters.map((device) => _buildPrinterCard(device)),
              const SizedBox(height: 16),
            ],

            // Paired printers section
            if (pairedPrinters.isNotEmpty) ...[
              _buildSectionHeader(
                'طابعات مقترنة',
                Icons.bluetooth_connected,
                Colors.blue,
                'Paired',
              ),
              ...pairedPrinters.map((device) => _buildPrinterCard(device)),
              const SizedBox(height: 16),
            ],

            // Discovered printers section
            if (discoveredPrinters.isNotEmpty) ...[
              _buildSectionHeader(
                'طابعات جديدة',
                Icons.bluetooth_searching,
                Colors.orange,
                'New - Requires Pairing',
              ),
              ...discoveredPrinters.map(
                (device) => _buildPrinterCard(device, isNew: true),
              ),
              const SizedBox(height: 16),
            ],

            // Unknown/Legacy printers
            if (unknownPrinters.isNotEmpty) ...[
              ...unknownPrinters.map((device) => _buildPrinterCard(device)),
            ],
          ],
        ),
      );
    }

    if (state is PrinterConnecting) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('جاري الاتصال بـ ${state.device.name}...'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.print, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'اضغط على "بحث عن طابعات" للبدء',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Build a view for when no Bluetooth printers are found
  Widget _buildNoBluetoothPrintersView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 64, color: Colors.orange[400]),
          const SizedBox(height: 16),
          const Text(
            'لم يتم العثور على طابعات بلوتوث',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'لإضافة طابعة، يرجى إقرانها في إعدادات الجهاز أولاً',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'كيفية إقران الطابعة:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStep('1', 'شغّل الطابعة الحرارية'),
                  _buildStep('2', 'افتح إعدادات البلوتوث في الأندرويد'),
                  _buildStep('3', 'اضغط "إقران جهاز جديد"'),
                  _buildStep('4', 'اختر الطابعة من القائمة'),
                  _buildStep('5', 'عد إلى التطبيق واضغط "بحث عن طابعات"'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings_bluetooth),
              label: const Text('فتح إعدادات البلوتوث'),
            ),
          ],
        ),
    );
  }

  /// Build a section header for printer groups
  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a printer card with source label
  Widget _buildPrinterCard(PrinterDevice device, {bool isNew = false}) {
    final sourceColor = _getSourceColor(device.sourceType);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNew
            ? BorderSide(color: Colors.orange.shade300, width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: _getConnectionColor(
                device.type,
              ).withOpacity(0.2),
              child: Icon(
                _getConnectionIcon(device.type),
                color: _getConnectionColor(device.type),
              ),
            ),
            if (device.sourceType != PrinterSourceType.unknown)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: sourceColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (device.sourceLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: sourceColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  device.sourceLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: sourceColor,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          device.address ?? 'لا يوجد عنوان',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: isNew
            ? OutlinedButton(
                onPressed: () {
                  // For new devices, open Bluetooth settings to pair first
                  openAppSettings();
                },
                child: const Text('إقران'),
              )
            : ElevatedButton(
                onPressed: () => _connectToPrinter(device),
                child: const Text('اتصال'),
              ),
      ),
    );
  }

  /// Get color for printer source type
  Color _getSourceColor(PrinterSourceType sourceType) {
    switch (sourceType) {
      case PrinterSourceType.builtIn:
        return Colors.green;
      case PrinterSourceType.paired:
        return Colors.blue;
      case PrinterSourceType.discovered:
        return Colors.orange;
      case PrinterSourceType.unknown:
        return Colors.grey;
    }
  }

  IconData _getConnectionIcon(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.wifi:
        return Icons.wifi;
      case PrinterConnectionType.bluetooth:
        return Icons.bluetooth;
      case PrinterConnectionType.manualConnect:
        return Icons.edit;
    }
  }

  Color _getConnectionColor(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.wifi:
        return Colors.blue;
      case PrinterConnectionType.bluetooth:
        return Colors.indigo;
      case PrinterConnectionType.manualConnect:
        return Colors.green;
    }
  }
}
