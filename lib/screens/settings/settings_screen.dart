import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubits/settings/settings_cubit.dart';
import '../../cubits/settings/settings_state.dart';
import '../../models/app_settings.dart';
import '../casher/printer_selection_screen.dart';

/// Main Settings Screen
/// Allows configuration of business info, invoice settings, and tax settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  late TextEditingController _businessNameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _taxNumberController;
  late TextEditingController _invoiceNotesController;
  late TextEditingController _taxValueController;

  bool _pricesIncludeTax = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _businessNameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _taxNumberController = TextEditingController();
    _invoiceNotesController = TextEditingController();
    _taxValueController = TextEditingController();

    // Load settings
    context.read<SettingsCubit>().loadSettings();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _taxNumberController.dispose();
    _invoiceNotesController.dispose();
    _taxValueController.dispose();
    super.dispose();
  }

  void _loadSettingsIntoForm(AppSettings settings) {
    _businessNameController.text = settings.businessName;
    _addressController.text = settings.address;
    _phoneController.text = settings.phoneNumber;
    _taxNumberController.text = settings.taxNumber;
    _invoiceNotesController.text = settings.invoiceNotes;
    _taxValueController.text = settings.taxValue.toString();
    setState(() {
      _pricesIncludeTax = settings.pricesIncludeTax;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final settings = AppSettings(
        businessName: _businessNameController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        taxNumber: _taxNumberController.text.trim(),
        invoiceNotes: _invoiceNotesController.text.trim(),
        taxValue: double.tryParse(_taxValueController.text) ?? 15.0,
        pricesIncludeTax: _pricesIncludeTax,
      );

      await context.read<SettingsCubit>().saveSettings(settings);
    }
  }

  Future<void> _refreshSettings() async {
    await context.read<SettingsCubit>().refreshFromApi();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('الإعدادات', style: theme.appBarTheme.titleTextStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث من السيرفر',
            onPressed: _refreshSettings,
          ),
        ],
      ),
      body: BlocConsumer<SettingsCubit, SettingsState>(
        listener: (context, state) {
          if (state is SettingsSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ تم حفظ الإعدادات بنجاح'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else if (state is SettingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (state is SettingsLoaded) {
            _loadSettingsIntoForm(state.settings);
          }
        },
        builder: (context, state) {
          if (state is SettingsLoading || state is SettingsInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sync Status Card
                  _buildSyncStatusCard(),
                  const SizedBox(height: 16),

                  // Business Information Section
                  _buildSectionHeader('معلومات المحل', Icons.business),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _businessNameController,
                    label: 'اسم المحل',
                    icon: Icons.store,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الرجاء إدخال اسم المحل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _addressController,
                    label: 'العنوان',
                    icon: Icons.location_on,
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الرجاء إدخال العنوان';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الرجاء إدخال رقم الهاتف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _taxNumberController,
                    label: 'الرقم الضريبي',
                    icon: Icons.receipt_long,
                  ),

                  const SizedBox(height: 32),

                  // Invoice Settings Section
                  _buildSectionHeader('إعدادات الفاتورة', Icons.description),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _invoiceNotesController,
                    label: 'ملاحظات الفاتورة',
                    hint: 'نص يظهر أسفل الفواتير المطبوعة',
                    icon: Icons.note,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 32),

                  // Tax Settings Section
                  _buildSectionHeader('إعدادات الضريبة', Icons.calculate),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _taxValueController,
                    label: 'قيمة الضريبة (%)',
                    icon: Icons.percent,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الرجاء إدخال قيمة الضريبة';
                      }
                      final num = double.tryParse(value);
                      if (num == null || num < 0 || num > 100) {
                        return 'الرجاء إدخال قيمة بين 0 و 100';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchTile(
                    title: 'الأسعار تشمل الضريبة',
                    subtitle: 'إذا كانت الأسعار المعروضة تشمل الضريبة',
                    value: _pricesIncludeTax,
                    onChanged: (value) {
                      setState(() {
                        _pricesIncludeTax = value;
                      });
                    },
                  ),

                  const SizedBox(height: 32),

                  // Printing Settings Button
                  _buildPrintingSettingsButton(),

                  const SizedBox(height: 24),

                  // Save Button
                  ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ الإعدادات'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPrintingSettingsButton() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.print, size: 32),
        title: const Text('إعدادات الطباعة'),
        subtitle: const Text('تكوين الطابعة وإعدادات الطباعة'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrinterSelectionScreen()),
          );
        },
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.cloud_sync, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مزامنة تلقائية مع السيرفر',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الإعدادات تُحمل من السيرفر تلقائياً',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
