# 🎨 UI INTEGRATION GUIDE - Manual Connection & Enhanced Discovery

## Overview

This guide shows how to integrate the new **ManualPrinterConnectionService** into your existing UI and enhance the printer selection screen to meet all requirements.

---

## 📋 Required UI Changes

### 1. Enhanced Printer Selection Screen

**Location:** Create or enhance `lib/screens/printer/printer_selection_screen.dart`

**Requirements:**
- ✅ Show bonded devices in dedicated section
- ✅ Show built-in printers (Sunmi)
- ✅ Show discovered devices
- ✅ Always show "Manual Connect" button
- ✅ Never show "No printers found" when bonded devices exist

### 2. Manual Connection Dialog

**Location:** Create `lib/screens/printer/manual_connection_dialog.dart`

**Requirements:**
- ✅ MAC address input field
- ✅ Format validation feedback
- ✅ Help text with examples
- ✅ Connect button with loading state
- ✅ Error display

---

## 💻 CODE IMPLEMENTATION

### Step 1: Create Manual Connection Dialog

```dart
// lib/screens/printer/manual_connection_dialog.dart

import 'package:flutter/material.dart';
import '../../services/manual_printer_connection_service.dart';
import '../../screens/casher/models/printer_device.dart';

class ManualConnectionDialog extends StatefulWidget {
  const ManualConnectionDialog({Key? key}) : super(key: key);

  @override
  State<ManualConnectionDialog> createState() => _ManualConnectionDialogState();
}

class _ManualConnectionDialogState extends State<ManualConnectionDialog> {
  final _macController = TextEditingController();
  final _nameController = TextEditingController();
  final _manualService = ManualPrinterConnectionService();
  
  bool _isConnecting = false;
  String? _errorMessage;
  bool _isValidFormat = false;

  @override
  void initState() {
    super.initState();
    _macController.addListener(_validateFormat);
  }

  void _validateFormat() {
    final input = _macController.text;
    final normalized = _manualService.validateAndNormalizeMacAddress(input);
    
    setState(() {
      _isValidFormat = normalized != null;
      if (_isValidFormat) {
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
    });

    try {
      final printer = await _manualService.connectByMacAddress(
        macAddress: macAddress,
        printerName: printerName,
      );

      if (mounted) {
        Navigator.of(context).pop(printer); // Return printer to caller
      }
    } on ManualConnectionException catch (e) {
      setState(() {
        _errorMessage = e.arabicMessage;
        _isConnecting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع: $e';
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'اتصال يدوي بالطابعة',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // MAC Address Input
            TextField(
              controller: _macController,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'عنوان MAC',
                hintText: 'AA:BB:CC:DD:EE:FF',
                helperText: 'الصيغة: AA:BB:CC:DD:EE:FF',
                prefixIcon: const Icon(Icons.bluetooth),
                suffixIcon: _isValidFormat
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                border: const OutlineInputBorder(),
              ),
              enabled: !_isConnecting,
            ),
            const SizedBox(height: 16),

            // Printer Name Input (Optional)
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الطابعة (اختياري)',
                hintText: 'مثال: طابعة المحل',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
              enabled: !_isConnecting,
            ),
            const SizedBox(height: 16),

            // Help Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'كيفية إيجاد عنوان MAC:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ..._manualService.getMacAddressInstructionsAr()
                      .split('\n')
                      .where((line) => line.trim().isNotEmpty)
                      .map((line) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              line,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )),
                ],
              ),
            ),

            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                  textAlign: TextAlign.center,
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
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isConnecting || !_isValidFormat)
                        ? null
                        : _connect,
                    child: _isConnecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('اتصال'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
```

### Step 2: Enhanced Printer Selection Screen

```dart
// lib/screens/printer/printer_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/printer/printer_cubit.dart';
import '../../cubits/printer/printer_state.dart';
import '../../screens/casher/models/printer_device.dart';
import 'manual_connection_dialog.dart';

class PrinterSelectionScreen extends StatefulWidget {
  const PrinterSelectionScreen({Key? key}) : super(key: key);

  @override
  State<PrinterSelectionScreen> createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Start scanning on init
    context.read<PrinterCubit>().scanPrinters(PrinterConnectionType.bluetooth);
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

  Widget _buildPrinterSection({
    required String title,
    required List<PrinterDevice> printers,
    String? emptyMessage,
  }) {
    if (printers.isEmpty && emptyMessage == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        if (printers.isEmpty && emptyMessage != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          )
        else
          ...printers.map((printer) => _buildPrinterTile(printer)),
        const Divider(),
      ],
    );
  }

  Widget _buildPrinterTile(PrinterDevice printer) {
    return ListTile(
      leading: Icon(
        printer.type == PrinterConnectionType.bluetooth
            ? Icons.bluetooth
            : Icons.print,
        size: 32,
      ),
      title: Text(printer.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (printer.address != null) Text(printer.address!),
          if (printer.sourceLabel.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getSourceColor(printer.sourceType),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                printer.sourceLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.read<PrinterCubit>().connectToPrinter(printer);
      },
    );
  }

  Color _getSourceColor(PrinterSourceType sourceType) {
    switch (sourceType) {
      case PrinterSourceType.builtIn:
        return Colors.purple;
      case PrinterSourceType.paired:
        return Colors.green;
      case PrinterSourceType.discovered:
        return Colors.blue;
      case PrinterSourceType.unknown:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختيار الطابعة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PrinterCubit>()
                  .scanPrinters(PrinterConnectionType.bluetooth);
            },
          ),
        ],
      ),
      body: BlocConsumer<PrinterCubit, PrinterState>(
        listener: (context, state) {
          if (state is PrinterConnected) {
            // Connection successful - return to previous screen
            Navigator.of(context).pop(state.device);
          } else if (state is PrinterError) {
            // Show error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is PrinterScanning) {
            return const Center(
              child: Column(
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
            // Organize printers by source type
            final builtInPrinters = state.devices
                .where((p) => p.sourceType == PrinterSourceType.builtIn)
                .toList();
            final pairedPrinters = state.devices
                .where((p) => p.sourceType == PrinterSourceType.paired)
                .toList();
            final discoveredPrinters = state.devices
                .where((p) => p.sourceType == PrinterSourceType.discovered)
                .toList();

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      // Built-in Printers Section
                      _buildPrinterSection(
                        title: 'الطابعات المدمجة',
                        printers: builtInPrinters,
                      ),

                      // Paired/Bonded Printers Section
                      _buildPrinterSection(
                        title: 'الطابعات المقترنة',
                        printers: pairedPrinters,
                        emptyMessage: 'لا توجد طابعات مقترنة.\n'
                            'قم بإقران طابعة من إعدادات البلوتوث أو استخدم الاتصال اليدوي.',
                      ),

                      // Discovered Printers Section
                      _buildPrinterSection(
                        title: 'طابعات جديدة',
                        printers: discoveredPrinters,
                      ),

                      // Manual Connection Section
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          onPressed: _showManualConnectionDialog,
                          icon: const Icon(Icons.edit),
                          label: const Text('اتصال يدوي (إدخال عنوان MAC)'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),

                      // Help Text
                      if (state.devices.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لم يتم العثور على طابعات',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'للاتصال بطابعة:\n\n'
                                  '1. تأكد من تشغيل البلوتوث\n'
                                  '2. قم بإقران الطابعة من إعدادات الأندرويد\n'
                                  '3. أو استخدم "اتصال يدوي" أدناه',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Default state
          return const Center(
            child: Text('اضغط على زر البحث للعثور على الطابعات'),
          );
        },
      ),
    );
  }
}
```

### Step 3: Integration with Existing Flow

Update your existing printer settings or connection flow:

```dart
// Example: In your cashier screen or settings screen

Future<void> _selectPrinter() async {
  final printer = await Navigator.of(context).push<PrinterDevice>(
    MaterialPageRoute(
      builder: (context) => const PrinterSelectionScreen(),
    ),
  );

  if (printer != null) {
    // Printer selected and connected
    setState(() {
      _selectedPrinter = printer;
    });
    
    // Save to preferences
    final settings = SettingsCubit();
    await settings.savePrinterSettings(
      PrinterSettings(
        selectedPrinter: printer,
        paperSize: PaperSize.mm58, // or mm80
        autoReconnect: true,
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم الاتصال بـ ${printer.name}'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
```

---

## 🎨 UI DESIGN RECOMMENDATIONS

### Printer Selection Screen Layout

```
┌─────────────────────────────────────┐
│  ← اختيار الطابعة            🔄    │ ← AppBar
├─────────────────────────────────────┤
│                                     │
│  الطابعات المدمجة                  │ ← Section Header
│  ┌─────────────────────────────┐   │
│  │ 🖨️  Sunmi InnerPrinter      │   │ ← Built-in Printer
│  │     [مدمجة]              >  │   │
│  └─────────────────────────────┘   │
│  ─────────────────────────────────  │ ← Divider
│                                     │
│  الطابعات المقترنة                 │ ← Section Header
│  ┌─────────────────────────────┐   │
│  │ 📶  XPrinter XP-58          │   │ ← Paired Printer
│  │     DC:0D:30:12:34:56       │   │
│  │     [مقترنة]              > │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 📶  GOOJPRT PT-210          │   │ ← Another Paired
│  │     AA:BB:CC:DD:EE:FF       │   │
│  │     [مقترنة]              > │   │
│  └─────────────────────────────┘   │
│  ─────────────────────────────────  │
│                                     │
│  طابعات جديدة                      │ ← Section Header
│  ┌─────────────────────────────┐   │
│  │ 📡  New Printer             │   │ ← Discovered
│  │     [جديدة]               >  │   │
│  └─────────────────────────────┘   │
│  ─────────────────────────────────  │
│                                     │
│  ┌═══════════════════════════════┐ │
│  ║ ✏️  اتصال يدوي (إدخال MAC)  ║ │ ← Manual Connect
│  └═══════════════════════════════┘ │
│                                     │
└─────────────────────────────────────┘
```

### Manual Connection Dialog Layout

```
┌─────────────────────────────────────┐
│  اتصال يدوي بالطابعة                │ ← Dialog Title
│                                     │
│  ┌───────────────────────────────┐ │
│  │ 📶  عنوان MAC                 │ │ ← MAC Input
│  │    AA:BB:CC:DD:EE:FF     ✓    │ │
│  │    الصيغة: AA:BB:CC:DD:EE:FF  │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ 🏷️  اسم الطابعة (اختياري)     │ │ ← Name Input
│  │    مثال: طابعة المحل           │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌─────────────────────────────────┤
│  │ ℹ️ كيفية إيجاد عنوان MAC:      │ ← Help Section
│  │ • في إعدادات البلوتوث          │
│  │ • في ملصق على الطابعة          │
│  │ • في دليل الاستخدام            │
│  └─────────────────────────────────┤
│                                     │
│  ┌─────────────┐  ┌──────────────┐ │
│  │   إلغاء     │  │    اتصال    │ │ ← Action Buttons
│  └─────────────┘  └──────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

---

## 🔌 INTEGRATION CHECKLIST

- [ ] Create `ManualConnectionDialog` widget
- [ ] Create or update `PrinterSelectionScreen`
- [ ] Add "Manual Connect" button to printer selection
- [ ] Organize printers by source type (built-in/paired/discovered)
- [ ] Show help message when no printers found
- [ ] Handle manual connection success
- [ ] Handle manual connection errors
- [ ] Save manually connected printers to preferences
- [ ] Test manual connection with valid MAC
- [ ] Test manual connection with invalid MAC
- [ ] Test error display and recovery

---

## 📱 USER EXPERIENCE FLOW

### Scenario 1: First Time User (No Paired Printers)

```
1. User opens app
2. Clicks "Printer Settings"
3. Sees "No paired printers" message
4. Clicks "Manual Connect"
5. Enters MAC address (from printer label)
6. Clicks "Connect"
7. Success! Printer connected and saved
8. Ready to print
```

### Scenario 2: Returning User (Has Paired Printer)

```
1. User opens app
2. Auto-reconnects to saved printer
3. Ready to print (zero interaction)
```

### Scenario 3: Paired Printer Not Showing in Discovery

```
1. User opens app
2. Clicks "Printer Settings"
3. Sees other devices but not their printer
4. Clicks "Manual Connect"
5. Enters known MAC address
6. Clicks "Connect"
7. Success! Printer connected
8. Ready to print
```

---

## 🎯 SUCCESS CRITERIA

After implementing this UI integration, you should have:

- ✅ Printer selection screen with clear sections
- ✅ Manual connect button always visible
- ✅ MAC address input with validation
- ✅ Help text for finding MAC addresses
- ✅ Error handling with user-friendly messages
- ✅ Success confirmation
- ✅ Persistent printer storage
- ✅ Auto-reconnect on app launch

---

## 📞 NEED HELP?

Refer to:
- `BLUETOOTH_QUICK_REFERENCE.md` for code patterns
- `PRODUCTION_BLUETOOTH_IMPLEMENTATION_GUIDE.md` for detailed documentation
- Service source files for implementation details

---

**END OF UI INTEGRATION GUIDE**
