import 'package:barber_casher/screens/casher/header_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cart_section.dart';
import 'categories_section.dart';
import 'models/service-model.dart';
import 'invoice_page.dart';
import 'printer_selection_screen.dart';
import '../settings/settings_screen.dart';
import '../../cubits/cashier/cashier_cubit.dart';
import '../../cubits/cashier/cashier_state.dart';
import 'shimmer_loading_widgets.dart';

class CashierScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const CashierScreen({super.key, required this.onToggleTheme});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  double _cartHeight = 250.0; // Default cart height
  final double _minCartHeight = 200.0;
  final double _maxCartHeight = 600.0;

  @override
  void initState() {
    super.initState();
    // Initialize data when screen opens
    context.read<CashierCubit>().initialize();
  }

  // All state is now managed by CashierCubit - no local state needed!

  void _showBarberSelectionSheet(ServiceModel service) {
    // Close keyboard when opening barber selection
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    String? localSelectedBarber;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return GestureDetector(
          onTap: () {
            // Prevent keyboard from opening when tapping inside the sheet
            FocusScope.of(sheetContext).unfocus();
          },
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'اختر الحلاق لخدمة "${service.name}"',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Get barbers from CashierCubit state
                BlocBuilder<CashierCubit, CashierState>(
                  builder: (context, state) {
                    if (state is! CashierLoaded) return const SizedBox();

                    return DropdownButtonFormField<String>(
                      hint: const Text('الرجاء اختيار حلاق'),
                      items: state.barbers.map((barber) {
                        return DropdownMenuItem(
                          value: barber,
                          child: Text(
                            barber,
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        localSelectedBarber = value;
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (localSelectedBarber != null) {
                            // Call cubit method instead of local method
                            context.read<CashierCubit>().addToCart(
                              service,
                              localSelectedBarber!,
                            );
                            Navigator.pop(sheetContext);
                          }
                        },
                        child: const Text('تأكيد'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ), // GestureDetector closing
        );
      },
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case "قص الشعر":
        return Icons.content_cut;
      case "حلاقة ذقن":
        return Icons.face_retouching_natural;
      case "العناية بالبشرة":
        return Icons.cleaning_services;
      case "الصبغات":
        return Icons.brush;
      case "استشوار":
        return Icons.air;
      case "تسريحة":
        return Icons.style;
      default:
        return Icons.cut;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 200).floor().clamp(2, 4);

    return BlocConsumer<CashierCubit, CashierState>(
      // Listen for one-time events like success/error messages
      listener: (context, state) {
        if (state is CashierItemAdded) {
          // Show success toast
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: Text('تمت إضافة "${state.service.name}" للسلة'),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 3),
          );
        } else if (state is CashierItemRemoved) {
          // Show removal toast
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            title: Text('تم حذف "${state.service.name}" من السلة'),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 3),
          );
        } else if (state is CashierError) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      // Build UI based on state
      builder: (context, state) {
        // Show loading indicator with shimmer
        if (state is CashierLoading || state is CashierInitial) {
          return Scaffold(
            appBar: AppBar(title: const Text("الكاشير")),
            body: CashierScreenShimmer(crossAxisCount: crossAxisCount),
          );
        }

        // Show error screen
        if (state is CashierError) {
          return Scaffold(
            appBar: AppBar(title: Text("الكاشير")),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<CashierCubit>().initialize(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        // Get loaded state (contains all data)
        final loadedState = state is CashierLoaded ? state : null;
        if (loadedState == null) {
          return Scaffold(
            appBar: AppBar(title: Text("الكاشير")),
            body: const Center(child: Text('حدث خطأ')),
          );
        }

        // Build main UI with data from state
        return Scaffold(
          appBar: AppBar(
            title: Text("الكاشير", style: theme.appBarTheme.titleTextStyle),
            actions: [
              // Settings button (NEW)
              IconButton(
                tooltip: "الإعدادات",
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              // Printer Settings button
              IconButton(
                tooltip: "إعدادات الطابعة",
                icon: const Icon(Icons.print),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrinterSelectionScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: isDarkMode
                    ? "التبديل إلى الوضع الفاتح"
                    : "التبديل إلى الوضع الداكن",
                icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                onPressed: widget.onToggleTheme,
              ),
              // Show invoice button only if cart has items
              if (loadedState.cart.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.receipt_long),
                  onPressed: () => _navigateToInvoice(context, loadedState),
                ),
            ],
          ),
          body: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                // Pass selected customer from state
                HeaderSection(
                  onCustomerSelected: (customer) {
                    context.read<CashierCubit>().selectCustomer(customer);
                  },
                ),
                CategoriesSection(
                  categories: loadedState.categories,
                  selectedCategory: loadedState.selectedCategory,
                  onCategorySelected: (cat) {
                    // Call cubit method to change category
                    context.read<CashierCubit>().selectCategory(cat);
                  },
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                Expanded(
                  child: Stack(
                    children: [
                      // Services Grid - Takes full height when cart is empty
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: loadedState.cart.isEmpty
                            ? 0
                            : _cartHeight, // Dynamic cart height
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 1.2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          // Use filtered services from state
                          itemCount: loadedState.filteredServices.length,
                          itemBuilder: (context, index) {
                            final service = loadedState.filteredServices[index];
                            return InkWell(
                              onTap: () {
                                // Close keyboard before showing barber selection
                                FocusScope.of(context).unfocus();
                                FocusManager.instance.primaryFocus?.unfocus();
                                // Small delay to ensure keyboard is closed
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () {
                                    _showBarberSelectionSheet(service);
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Card(
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Show image from API or fallback to icon
                                      service.image.isNotEmpty &&
                                              (service.image.startsWith(
                                                    'http://',
                                                  ) ||
                                                  service.image.startsWith(
                                                    'https://',
                                                  ))
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                service.image,
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      // Fallback to icon if image fails to load
                                                      return Icon(
                                                        _getIconForCategory(
                                                          service.category,
                                                        ),
                                                        size: 32,
                                                        color: theme
                                                            .colorScheme
                                                            .secondary,
                                                      );
                                                    },
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null)
                                                    return child;
                                                  return SizedBox(
                                                    width: 50,
                                                    height: 50,
                                                    child: Center(
                                                      child: CircularProgressIndicator(
                                                        value:
                                                            loadingProgress
                                                                    .expectedTotalBytes !=
                                                                null
                                                            ? loadingProgress
                                                                      .cumulativeBytesLoaded /
                                                                  loadingProgress
                                                                      .expectedTotalBytes!
                                                            : null,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                          : Icon(
                                              _getIconForCategory(
                                                service.category,
                                              ),
                                              size: 32,
                                              color:
                                                  theme.colorScheme.secondary,
                                            ),
                                      const SizedBox(height: 8),
                                      Flexible(
                                        child: Text(
                                          service.name,
                                          style: theme.textTheme.titleMedium,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${service.price.toStringAsFixed(0)} ر.س",
                                        style: GoogleFonts.cairo(
                                          color: theme.colorScheme.secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Animated Cart Section - Draggable from bottom
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        left: 0,
                        right: 0,
                        bottom: loadedState.cart.isEmpty
                            ? -_cartHeight
                            : 0, // Hidden below screen when empty
                        height: _cartHeight, // Dynamic height
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: loadedState.cart.isEmpty ? 0.0 : 1.0,
                          child: GestureDetector(
                            onVerticalDragStart: (details) {
                              // Haptic feedback when drag starts
                              HapticFeedback.selectionClick();
                            },
                            onVerticalDragUpdate: (details) {
                              setState(() {
                                // Dragging down increases height, dragging up decreases
                                _cartHeight = (_cartHeight - details.delta.dy)
                                    .clamp(_minCartHeight, _maxCartHeight);
                              });
                            },
                            onVerticalDragEnd: (details) {
                              // Haptic feedback when drag ends
                              HapticFeedback.mediumImpact();
                            },
                            child: CartSection(
                              cart: loadedState.cart,
                              removeFromCart: (index) {
                                // Call cubit method to remove item
                                context.read<CashierCubit>().removeFromCart(
                                  index,
                                );
                              },
                              selectedCustomer: loadedState.selectedCustomer,
                              navigateToInvoice: () =>
                                  _navigateToInvoice(context, loadedState),
                            ),
                          ), // GestureDetector closing
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToInvoice(BuildContext context, CashierLoaded state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePage(
          cart: List<ServiceModel>.from(state.cart),
          customer: state.selectedCustomer,
        ),
      ),
    );
  }
}
