import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/printer/printer_cubit.dart';
import '../../cubits/printer/printer_state.dart';
import '../../models/printer_settings.dart';
import '../../models/invoice_data.dart';
import '../thermal_receipt_preview_screen.dart';
import 'models/printer_device.dart';
import 'package:toastification/toastification.dart';
import '../../helpers/system_settings_helper.dart';
import '../../helpers/validation_guard_mixin.dart';

/// Professional Printer Settings screen with full configuration options
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen>
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

  void _scanPrinters() async {
    // Validate environment before scanning
    final isValid = await validateBeforePrinterOperation(
      operationName: 'scan for printers',
    );

    if (!isValid) return;

    context.read<PrinterCubit>().scanPrinters(_selectedType);
  }

  void _connectToPrinter(PrinterDevice device) async {
    // Validate environment before connecting
    final isValid = await validateBeforePrinterOperation(
      operationName: 'connect to printer',
    );

    if (!isValid) return;

    context.read<PrinterCubit>().connectToPrinter(device);
  }

  void _disconnect() {
    context.read<PrinterCubit>().disconnect();
  }

  void _testPrint() {
    context.read<PrinterCubit>().testPrint();
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

  void _showBluetoothPairingGuidance() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(child: Text('لم يتم العثور على طابعات مقترنة')),
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
                        'ملاحظة: يجب إقران الطابعة عبر إعدادات البلوتوث في الجهاز قبل الاتصال بها من هذا التطبيق.',
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
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            onPressed: () {
              Navigator.pop(context);
              SystemSettingsHelper.openBluetoothSettings();
            },
            icon: const Icon(Icons.settings_bluetooth),
            label: const Text(
              'فتح إعدادات البلوتوث',
              style: TextStyle(fontSize: 14),
            ),
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
            decoration: const BoxDecoration(
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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showReceiptPreview() {
    // Create sample invoice data for preview
    final testData = InvoiceData(
      orderNumber: '104',
      branchName: 'الفرع الرئيسي',
      cashierName: 'Yousef',
      dateTime: DateTime.now(),
      customerName: 'عميل كاش',
      customerPhone: null,
      items: [
        InvoiceItem(
          name: 'قص',
          price: 25.00,
          quantity: 1,
          employeeName: 'محمد',
        ),
      ],
      subtotalBeforeTax: 25.00,
      discountPercentage: 0.0,
      discountAmount: 0.0,
      amountAfterDiscount: 25.00,
      taxRate: 15.0,
      taxAmount: 3.75,
      grandTotal: 28.75,
      paymentMethod: 'نقدي',
      paidAmount: 28.75,
      remainingAmount: 0.0,
      invoiceNotes: null,
      businessName: 'صالون الشباب',
      businessAddress: 'الصبخة البحرية',
      businessPhone: '0566666464',
      taxNumber: 'TAX123456789',
      logoPath: 'assets/images/logo.png',
    );

    // Navigate to preview screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThermalReceiptPreviewScreen(
          data: testData,
          paperWidth: _selectedPaperSize == PaperSize.mm58
              ? PaperWidth.mm58
              : PaperWidth.mm80,
          onPrint: () {
            Navigator.pop(context);
            toastification.show(
              context: context,
              title: const Text(
                'هذا مجرد معاينة - يمكنك طباعة الفواتير الفعلية من شاشة الفاتورة',
              ),
              type: ToastificationType.info,
              autoCloseDuration: const Duration(seconds: 3),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الطابعة'),
        centerTitle: true,
        elevation: 2,
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
            toastification.show(
              context: context,
              title: Text(state.message),
              type: ToastificationType.error,
              autoCloseDuration: const Duration(seconds: 3),
            );
          } else if (state is PrinterDisconnected) {
            toastification.show(
              context: context,
              title: const Text('تم قطع الاتصال بالطابعة'),
              type: ToastificationType.info,
              autoCloseDuration: const Duration(seconds: 2),
            );
          } else if (state is PrinterPrintSuccess) {
            toastification.show(
              context: context,
              title: const Text('تمت الطباعة التجريبية بنجاح!'),
              type: ToastificationType.success,
              autoCloseDuration: const Duration(seconds: 2),
            );
          } else if (state is PrintersFound &&
              state.devices.isEmpty &&
              state.type == PrinterConnectionType.bluetooth) {
            // Show Bluetooth pairing guidance when no printers found
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showBluetoothPairingGuidance();
            });
          }
        },
        builder: (context, state) {
          final isConnected = state is PrinterConnected;
          final isPrinting = state is PrinterPrinting;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Paper Size Section
                _buildPaperSizeSection(theme),

                const Divider(height: 1),

                // Connection Status Banner
                if (state is PrinterConnected) _buildConnectedBanner(state),

                // Connection Type Tabs
                _buildConnectionTypeTabs(theme),

                // Scan Button
                _buildScanButton(state),

                // Printers List
                _buildPrintersList(state),

                // Test Print Button (shown when connected)
                if (isConnected && !isPrinting) _buildTestPrintButton(theme),

                // Printing indicator
                if (isPrinting) _buildPrintingIndicator(),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
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
          const SizedBox(height: 16),
          // Preview Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showReceiptPreview,
              icon: const Icon(Icons.visibility),
              label: const Text('معاينة نموذج الفاتورة'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedBanner(PrinterConnected state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الطابعة المتصلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.device.displayName,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.link_off, color: Colors.white),
            onPressed: _disconnect,
            tooltip: 'قطع الاتصال',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTypeTabs(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.textTheme.bodyMedium?.color,
        indicatorColor: theme.colorScheme.primary,
        tabs: const [
          Tab(icon: Icon(Icons.wifi), text: 'WiFi'),
          Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
          Tab(icon: Icon(Icons.usb), text: 'USB'),
        ],
      ),
    );
  }

  Widget _buildScanButton(PrinterState state) {
    final isScanning = state is PrinterScanning;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: isScanning ? null : _scanPrinters,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: isScanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.search),
        label: Text(
          isScanning ? 'جاري البحث...' : 'بحث عن طابعات',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPrintersList(PrinterState state) {
    if (state is PrinterScanning) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري البحث عن الطابعات...'),
          ],
        ),
      );
    }

    if (state is PrintersFound) {
      if (state.devices.isEmpty) {
        // Different messages based on connection type
        String message = 'تأكد من تشغيل الطابعة واتصالها بالشبكة';

        if (state.type == PrinterConnectionType.bluetooth) {
          message = 'تأكد من إقران الطابعة عبر إعدادات البلوتوث أولاً';
        } else if (state.type == PrinterConnectionType.wifi) {
          message = 'تأكد من تشغيل الطابعة واتصالها بنفس الشبكة';
        }

        return Container(
          height: 200,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.print_disabled, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'لم يتم العثور على طابعات',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.devices.length,
        itemBuilder: (context, index) {
          final device = state.devices[index];
          return _buildPrinterTile(device, state is PrinterConnected);
        },
      );
    }

    // Empty state
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'انقر على "بحث عن طابعات" للبدء',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterTile(PrinterDevice device, bool isAnyConnected) {
    final theme = Theme.of(context);
    final cubit = context.read<PrinterCubit>();
    final isThisConnected = cubit.connectedPrinter?.id == device.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isThisConnected ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isThisConnected
              ? theme.colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isThisConnected
              ? theme.colorScheme.primary
              : theme.colorScheme.primaryContainer,
          child: Icon(
            _getConnectionTypeIcon(device.type),
            color: isThisConnected ? Colors.white : theme.colorScheme.primary,
          ),
        ),
        title: Text(
          device.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isThisConnected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              device.type.toString().split('.').last.toUpperCase(),
              style: theme.textTheme.bodySmall,
            ),
            if (device.address != null) ...[
              const SizedBox(height: 2),
              Text(
                device.address!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
        trailing: isThisConnected
            ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
            : ElevatedButton(
                onPressed: () => _connectToPrinter(device),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('اتصال'),
              ),
      ),
    );
  }

  Widget _buildTestPrintButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        onPressed: _testPrint,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: theme.colorScheme.primary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(Icons.print, color: theme.colorScheme.primary),
        label: Text(
          'طباعة تجريبية',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildPrintingIndicator() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 16),
          Text(
            'جاري الطباعة...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getConnectionTypeIcon(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.wifi:
        return Icons.wifi;
      case PrinterConnectionType.bluetooth:
        return Icons.bluetooth;
      case PrinterConnectionType.manualConnect:
        return Icons.edit;
    }
  }
}
