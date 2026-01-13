# 🚀 BLUETOOTH PRINTING QUICK REFERENCE

## 🎯 GOLDEN RULES

1. **ALWAYS validate environment before any Bluetooth operation**
2. **NEVER filter bonded devices** - show ALL of them
3. **ALWAYS provide manual connection option**
4. **ALWAYS validate before printing**
5. **NEVER claim success without verification**

---

## 📝 CODE RECIPES

### Recipe 1: Scan for Printers

```dart
// Step 1: Validate environment
final envService = BluetoothEnvironmentService();
final envCheck = await envService.performPreFlightCheck();

if (!envCheck.isReady) {
  // Show error and abort
  showError(envCheck.readableMessage);
  return;
}

// Step 2: Discover printers
final discoveryService = UnifiedPrinterDiscoveryService();
final result = await discoveryService.discoverAllPrinters();

// Step 3: Show results
if (result.allPrinters.isEmpty) {
  // Show "Manual Connect" option
  showManualConnectDialog();
} else {
  // Show printer list
  showPrinterList(result.allPrinters);
}
```

### Recipe 2: Manual Connection

```dart
// Get user input
final macAddress = await showMacAddressInputDialog();

// Validate format
final manualService = ManualPrinterConnectionService();
final normalized = manualService.validateAndNormalizeMacAddress(macAddress);

if (normalized == null) {
  showError('عنوان MAC غير صحيح');
  return;
}

// Attempt connection
try {
  final printer = await manualService.connectByMacAddress(
    macAddress: normalized,
    printerName: 'My Printer',
  );
  
  // Save printer
  await savePrinterToPreferences(printer);
  
  // Success
  showSuccess('تم الاتصال بالطابعة');
} on ManualConnectionException catch (e) {
  showError(e.arabicMessage);
}
```

### Recipe 3: Print with Validation

```dart
// Generate receipt bytes
final bytes = await ImageBasedThermalPrinter.generateImageBasedReceipt(
  invoiceData,
  paperSize: PaperSize.mm58,
);

// Pre-print validation
final validator = PrinterConnectionValidator();
final healthCheck = await validator.validateBeforePrint(connectedPrinter);

if (!healthCheck.canPrint) {
  showError(healthCheck.errorMessage);
  return;
}

// Send to printer
final success = await _bluetooth.writeBytes(bytes);

if (!success) {
  throw PrinterError.writeFailed();
}

// Post-print verification
final transmitted = await validator.validateAfterPrint();

if (transmitted) {
  showSuccess('تمت الطباعة بنجاح');
} else {
  showWarning('قد تكون الطباعة غير مكتملة');
}
```

### Recipe 4: Auto-Reconnect on Launch

```dart
Future<void> initializePrinter() async {
  // Load saved printer
  final savedPrinter = await loadPrinterFromPreferences();
  
  if (savedPrinter == null) {
    // No saved printer - show selection
    showPrinterSelection();
    return;
  }
  
  // Validate environment
  final envService = BluetoothEnvironmentService();
  final envCheck = await envService.performPreFlightCheck();
  
  if (!envCheck.isReady) {
    // Environment not ready - show error
    showError(envCheck.readableMessage);
    return;
  }
  
  // Attempt auto-reconnect
  try {
    final device = BluetoothDevice(
      savedPrinter.address!,
      savedPrinter.name,
    );
    
    await _bluetooth.connect(device);
    
    // Verify connection
    final isConnected = await _bluetooth.isConnected;
    
    if (isConnected == true) {
      // Success - ready to print
      setState(() {
        connectedPrinter = savedPrinter;
      });
    } else {
      // Failed - show selection
      showPrinterSelection();
    }
  } catch (e) {
    // Connection failed - show selection
    logger.w('Auto-reconnect failed: $e');
    showPrinterSelection();
  }
}
```

---

## 🔍 ERROR HANDLING CHEATSHEET

```dart
try {
  await bluetoothOperation();
} on ManualConnectionException catch (e) {
  // Manual connection specific error
  showErrorDialog(
    title: e.arabicTitle,
    message: e.arabicMessage,
    suggestions: e.suggestions,
  );
} on PrinterError catch (e) {
  // Structured printer error
  showErrorDialog(
    title: e.arabicTitle,
    message: e.arabicMessage,
    suggestions: e.suggestions,
  );
} catch (e) {
  // Unknown error - map it
  final printerError = PrinterErrorMapper().mapError(e);
  showErrorDialog(
    title: printerError.arabicTitle,
    message: printerError.arabicMessage,
    suggestions: printerError.suggestions,
  );
}
```

---

## 🎨 UI PATTERNS

### Printer Selection Screen

```dart
// ALWAYS show in this order:
1. Built-in Printers (if any)
   └─ Show first, with clear indicator

2. Paired Bluetooth Devices
   └─ ALWAYS show ALL bonded devices
   └─ NEVER filter by name
   
3. Discovered Devices (if any)
   └─ Show with "جديدة" badge
   
4. Manual Connect Button
   └─ ALWAYS visible
   └─ Opens MAC address input dialog
```

### Error Display

```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(error.arabicTitle),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(error.arabicMessage),
        if (error.suggestions.isNotEmpty) ...[
          SizedBox(height: 16),
          Text('الحلول المقترحة:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...error.suggestions.map((s) => Text('• $s')),
        ],
      ],
    ),
    actions: [
      if (error.isRecoverable)
        TextButton(
          onPressed: () => retry(),
          child: Text('إعادة المحاولة'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('حسناً'),
      ),
    ],
  ),
);
```

---

## 📊 COMMON ERROR CODES

| Code | Meaning | User Action |
|------|---------|-------------|
| E002 | Bluetooth disabled | Enable in settings |
| E003 | Location disabled | Enable location (Android < 12) |
| E004 | Permission denied | Grant permissions |
| E103 | Connection timeout | Move closer to printer |
| E104 | Pairing required | Pair in Android settings |
| E107 | Printer not reachable | Power on printer |
| E302 | Write failed | Reconnect printer |

---

## 🧪 TESTING CHECKLIST

- [ ] Bluetooth disabled → Shows clear error
- [ ] Location disabled (Android < 12) → Shows clear error
- [ ] Permissions denied → Request permissions
- [ ] No printers paired → Shows manual connect
- [ ] Paired printer always appears in list
- [ ] Manual connect with valid MAC → Connects
- [ ] Manual connect with invalid MAC → Shows error
- [ ] Printer powered off → Connection timeout
- [ ] Auto-reconnect on launch works
- [ ] Auto-reconnect failure → Falls back gracefully
- [ ] Print with validation → Succeeds
- [ ] Print without connection → Shows error
- [ ] Arabic text renders correctly
- [ ] 58mm and 80mm receipts print correctly

---

## 🔗 SERVICE DEPENDENCIES

```
PrinterService
  ├── BluetoothEnvironmentService
  ├── UnifiedPrinterDiscoveryService
  ├── ManualPrinterConnectionService
  ├── PrinterConnectionValidator
  ├── PrinterErrorMapper
  ├── ImageBasedThermalPrinter
  └── EscPosRasterGenerator
```

---

## 💡 PRO TIPS

1. **Always validate before operations**
   - Check environment before discovery
   - Check health before printing
   - Verify after printing

2. **Use structured errors**
   - Catch specific exception types
   - Map unknown errors
   - Show Arabic messages to users

3. **Provide fallbacks**
   - Auto discovery fails? → Manual connect
   - Auto-reconnect fails? → Show selection
   - Environment not ready? → Clear instructions

4. **Test on real devices**
   - Emulators don't have Bluetooth
   - Test on Android 8-14
   - Test with different printer brands

5. **Log everything**
   - Use Logger for diagnostics
   - Include error codes in logs
   - Log connection state changes

---

## 📱 PLATFORM REQUIREMENTS

### Android Manifest
```xml
<!-- Android 8-11 -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>

<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
    android:usesPermissionFlags="neverForLocation" />
```

### Gradle (android/app/build.gradle)
```gradle
minSdkVersion 26  // Android 8
targetSdkVersion 34  // Android 14
```

---

## 🆘 EMERGENCY DEBUGGING

If everything fails:

```dart
// Enable verbose logging
Logger.level = Level.debug;

// Check Bluetooth state
final bluetooth = BlueThermalPrinter.instance;
final isAvailable = await bluetooth.isAvailable;
final isOn = await bluetooth.isOn;
final isConnected = await bluetooth.isConnected;

print('Available: $isAvailable');
print('Enabled: $isOn');
print('Connected: $isConnected');

// Check bonded devices
final bonded = await bluetooth.getBondedDevices();
print('Bonded devices: ${bonded.length}');
for (var device in bonded) {
  print('  - ${device.name}: ${device.address}');
}

// Check permissions (Android 12+)
final connectStatus = await Permission.bluetoothConnect.status;
print('BLUETOOTH_CONNECT: $connectStatus');
```

---

**Last Updated:** January 13, 2026
