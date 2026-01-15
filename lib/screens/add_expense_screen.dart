import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../models/participant.dart';
import '../providers/app_providers.dart';
import '../utils/constants.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String tripId;
  final Expense? expenseToEdit;

  const AddExpenseScreen({super.key, required this.tripId, this.expenseToEdit});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  static const double _maxExpenseAmount = 10000000.0; // 10,000,000

  String? _selectedPayerId;
  SplitType _splitType = SplitType.equal;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  final Map<String, TextEditingController> _shareControllers = {};
  // Track last valid exact values per participant to allow revert on overflow
  final Map<String, String> _lastValidExact = {};
  // Track last valid percentage values per participant to cap by remaining
  final Map<String, String> _lastValidPercentage = {};
  bool _isSubmitting = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (var controller in _shareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeWithExpense() {
    if (_isInitialized || widget.expenseToEdit == null) return;
    _isInitialized = true;

    final expense = widget.expenseToEdit!;
    _descriptionController.text = expense.description;
    _amountController.text = expense.amount.toStringAsFixed(2);
    _selectedPayerId = expense.payerId;
    _splitType = expense.splitType;
    _selectedCategory = expense.category;
    _selectedDate = expense.date;

    // Initialize share controllers with existing values
    // For percentage/exact split, use splitMeta values; for others use calculated amounts
    if (expense.splitType == SplitType.percentage ||
        expense.splitType == SplitType.exact) {
      // Use the original splitMeta values (percentage, shares, or exact amounts)
      for (var entry in expense.splitMeta.entries) {
        final controller = _shareControllers[entry.key];
        if (controller != null) {
          controller.text = entry.value.toStringAsFixed(2);
          if (expense.splitType == SplitType.percentage) {
            _lastValidPercentage[entry.key] = controller.text;
          } else {
            _lastValidExact[entry.key] = controller.text;
          }
        }
      }
    } else {
      // For other types, use calculated amounts
      for (var share in expense.shares) {
        final controller = _shareControllers[share.participantId];
        if (controller != null) {
          controller.text = share.amountInBase.toStringAsFixed(2);
        }
      }
    }
  }

  double _calculateTotalPercentage() {
    double total = 0;
    for (var controller in _shareControllers.values) {
      final value = double.tryParse(controller.text.trim()) ?? 0;
      total += value;
    }
    return total;
  }

  double _calculateExactTotal() {
    double total = 0;
    for (var controller in _shareControllers.values) {
      final value = double.tryParse(controller.text.trim()) ?? 0;
      total += value;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final participantsAsync = ref.watch(
      tripParticipantsProvider(widget.tripId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.expenseToEdit != null ? 'Edit Expense' : 'Add Expense',
        ),
      ),
      body: tripAsync.when(
        data: (trip) {
          if (trip == null) {
            return const Center(child: Text('Trip not found'));
          }

          // Lock currency to trip's base currency (or existing expense currency when editing)
          final expenseCurrency =
              widget.expenseToEdit?.expenseCurrency ?? trip.baseCurrency;

          return participantsAsync.when(
            data: (participants) {
              if (participants.isEmpty) {
                return const Center(child: Text('Add participants first'));
              }

              // Initialize share controllers for all participants
              for (var participant in participants) {
                _shareControllers.putIfAbsent(
                  participant.id,
                  () => TextEditingController(),
                );
                _lastValidExact.putIfAbsent(participant.id, () => '');
                _lastValidPercentage.putIfAbsent(participant.id, () => '');
              }

              // Initialize form with existing expense data if editing
              _initializeWithExpense();

              return Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16 + MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 110,
                      inputFormatters: [DescriptionFormatter()],
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g., Lunch at restaurant',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: validateExpenseDescription,
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        prefix: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            _currencySymbol(expenseCurrency),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        _AmountInputFormatter(max: _maxExpenseAmount),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter amount';
                        }
                        final trimmed = value.trim();
                        // Must be numeric with up to 2 decimals
                        if (!_validMoneyPrecision(trimmed)) {
                          return 'Use numbers with max 2 decimals';
                        }
                        final numVal = double.tryParse(trimmed);
                        if (numVal == null) {
                          return 'Invalid amount';
                        }
                        if (numVal <= 0) {
                          return 'Amount must be greater than 0';
                        }
                        if (numVal > _maxExpenseAmount) {
                          return 'Max allowed is 10,000,000';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Payer
                    DropdownButtonFormField<String>(
                      value: _selectedPayerId,
                      decoration: InputDecoration(
                        labelText: 'Paid by',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      dropdownColor: Theme.of(context).cardColor,
                      menuMaxHeight: 280,
                      items: participants.map((participant) {
                        return DropdownMenuItem(
                          value: participant.id,
                          child: Text(participant.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedPayerId = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select who paid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDate.toString().split(' ')[0],
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      dropdownColor: Theme.of(context).cardColor,
                      menuMaxHeight: 400,
                      items: expenseCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Split Type
                    DropdownButtonFormField<SplitType>(
                      value: _splitType,
                      decoration: InputDecoration(
                        labelText: 'Split Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      dropdownColor: Theme.of(context).cardColor,
                      menuMaxHeight: 280,
                      items: SplitType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_formatSplitType(type)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final previousType = _splitType;
                          setState(() => _splitType = value);

                          // Clear split detail fields whenever type changes
                          if (previousType != value) {
                            for (var controller in _shareControllers.values) {
                              controller.clear();
                            }
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Split details (if not equal)
                    if (_splitType != SplitType.equal) ...[
                      const Text(
                        'Split Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...participants.map((participant) {
                        final controller = _shareControllers[participant.id]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextFormField(
                            controller: controller,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              labelText: participant.displayName,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              hintText: _getSplitHint(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: _splitType == SplitType.percentage
                                ? [_PercentageInputFormatter()]
                                : _splitType == SplitType.exact
                                ? [_MoneyInputFormatter()]
                                : null,
                            onChanged: (_) {
                              if (_splitType == SplitType.percentage) {
                                // Enforce dynamic remaining cap per participant
                                double sumOthers = 0.0;
                                _shareControllers.forEach((pid, ctrl) {
                                  if (pid != participant.id) {
                                    final v = double.tryParse(ctrl.text.trim()) ?? 0.0;
                                    sumOthers += v;
                                  }
                                });
                                final remaining = 100.0 - sumOthers;
                                final current = double.tryParse(controller.text.trim());

                                // Allow empty while typing; just update and repaint
                                if (current == null) {
                                  _lastValidPercentage[participant.id] = controller.text;
                                  setState(() {});
                                  return;
                                }

                                // Block negative values defensively and cap by remaining (with tolerance)
                                if (current < -0.000001 || (current - remaining) > 0.000001) {
                                  final prev = _lastValidPercentage[participant.id] ?? '';
                                  controller.value = controller.value.copyWith(
                                    text: prev,
                                    selection: TextSelection.collapsed(offset: prev.length),
                                  );
                                } else {
                                  // Update last valid on successful change
                                  _lastValidPercentage[participant.id] = controller.text;
                                  setState(() {});
                                }
                              } else if (_splitType == SplitType.exact) {
                                final amountValue = double.tryParse(
                                  _amountController.text.trim(),
                                );
                                if (amountValue != null) {
                                  final total = _calculateExactTotal();
                                  // Block/revert if exceeding total while typing
                                  if ((total - amountValue) > 0.000001) {
                                    final prev =
                                        _lastValidExact[participant.id] ?? '';
                                    controller.value = controller.value
                                        .copyWith(
                                          text: prev,
                                          selection: TextSelection.collapsed(
                                            offset: prev.length,
                                          ),
                                        );
                                  } else {
                                    // Update last valid on successful change
                                    _lastValidExact[participant.id] =
                                        controller.text;
                                    setState(() {});
                                  }
                                } else {
                                  // No amount yet; just track last valid and update UI
                                  _lastValidExact[participant.id] =
                                      controller.text;
                                  setState(() {});
                                }
                              }
                            },
                            validator: _splitType == SplitType.percentage
                                ? (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter percentage';
                                    }
                                    final num = double.tryParse(value);
                                    if (num == null) {
                                      return 'Invalid number';
                                    }
                                    if (num < 0 || num > 100) {
                                      return 'Must be 0-100';
                                    }
                                    return null;
                                  }
                                : _splitType == SplitType.exact
                                ? (value) {
                                    final trimmed = value?.trim() ?? '';
                                    if (trimmed.isEmpty) {
                                      return 'Enter amount';
                                    }
                                    final num = double.tryParse(trimmed);
                                    if (num == null) {
                                      return 'Invalid amount';
                                    }
                                    if (num < 0) {
                                      return 'Cannot be negative';
                                    }
                                    if (!_validMoneyPrecision(trimmed)) {
                                      return 'Max 2 decimals';
                                    }
                                    return null;
                                  }
                                : null,
                          ),
                        );
                      }),
                      if (_splitType == SplitType.percentage) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final total = _calculateTotalPercentage();
                            final isValid = (total - 100).abs() < 0.01;
                            final remaining = (100 - total);
                            final remainingClamped = remaining < 0 ? 0 : remaining;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isValid
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isValid ? Colors.green : Colors.orange,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isValid
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '${total.toStringAsFixed(2)}% • Remaining: ${remainingClamped.toStringAsFixed(2)}% ${isValid ? '✓' : '(must equal 100%)'}',
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isValid
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      if (_splitType == SplitType.exact) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final amountValue = double.tryParse(
                              _amountController.text.trim(),
                            );
                            final total = _calculateExactTotal();
                            final isValid =
                                amountValue != null &&
                                (total - amountValue).abs() < 0.01;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isValid
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isValid ? Colors.green : Colors.orange,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isValid
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        amountValue == null
                                            ? '${total.toStringAsFixed(2)} (enter amount first)'
                                            : '${total.toStringAsFixed(2)} / ${amountValue.toStringAsFixed(2)} ${isValid ? '✓' : '(must equal amount)'}',
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isValid
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 24),

                    // Submit Button
                    // Disable for Percentage until total == 100, and for Exact until totals match
                    Builder(
                      builder: (context) {
                        final totalPercent = _calculateTotalPercentage();
                        final canSubmit = _splitType == SplitType.exact
                            ? _isExactSplitValid(participants)
                            : _splitType == SplitType.percentage
                                ? (totalPercent - 100).abs() < 0.01
                                : true;
                        return FilledButton(
                          onPressed: _isSubmitting || !canSubmit
                              ? null
                              : () => _submitExpense(
                                  trip.baseCurrency,
                                  expenseCurrency,
                                  participants,
                                ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  widget.expenseToEdit != null
                                      ? 'Update Expense'
                                      : 'Add Expense',
                                ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  String _getSplitHint() {
    switch (_splitType) {
      case SplitType.percentage:
        return 'Percentage (%)';
      case SplitType.exact:
        return 'Exact amount';
      default:
        return '';
    }
  }

  String _formatSplitType(SplitType type) {
    switch (type) {
      case SplitType.equal:
        return 'Equal';
      case SplitType.percentage:
        return 'Percentage';
      case SplitType.exact:
        return 'Exact';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _currencySymbol(String code) {
    const symbols = {
      'USD': '\$', // $
      'CAD': 'CA\$',
      'AUD': 'A\$',
      'SGD': 'S\$',
      'HKD': 'HK\$',
      'EUR': '€',
      'GBP': '£',
      'INR': '₹',
      'JPY': 'JP¥',
      'CNY': 'CN¥',
      'AED': 'AED',
      'SAR': 'SAR',
      'QAR': 'QAR',
      'THB': '฿',
      'CHF': 'CHF',
      'OMR': 'OMR',
      'NOK': 'NOK',
      'SEK': 'SEK',
      'DKK': 'DKK',
      'KRW': '₩',
      'IDR': 'Rp',
      'MYR': 'RM',
      'VND': '₫',
    };
    return symbols[code] ?? code;
  }

  bool _validMoneyPrecision(String value) {
    return RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value);
  }

  // Validate Exact split fields: all non-empty, valid money, non-negative, totals equal amount
  bool _isExactSplitValid(List participants) {
    final amountValue = double.tryParse(_amountController.text.trim());
    if (amountValue == null) return false;

    double sum = 0.0;
    for (var participant in participants) {
      final controller = _shareControllers[participant.id];
      final trimmed = controller?.text.trim() ?? '';
      if (trimmed.isEmpty) return false;
      final numVal = double.tryParse(trimmed);
      if (numVal == null) return false;
      if (numVal < 0) return false;
      if (!_validMoneyPrecision(trimmed)) return false;
      sum += numVal;
    }

    return (sum - amountValue).abs() < 0.01;
  }

  Future<void> _submitExpense(
    String baseCurrency,
    String expenseCurrency,
    List participants,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate percentage total equals 100
    if (_splitType == SplitType.percentage) {
      final total = _calculateTotalPercentage();
      if ((total - 100).abs() >= 0.01) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Total percentage must equal 100% (current: ${total.toStringAsFixed(2)}%)',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    // Validate exact total equals amount
    if (_splitType == SplitType.exact) {
      final amountValue = double.tryParse(_amountController.text.trim());
      if (amountValue == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Enter a valid amount before setting exact splits.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      final exactTotal = _calculateExactTotal();
      if ((exactTotal - amountValue).abs() >= 0.01) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Exact amounts must total the expense amount (current: ${exactTotal.toStringAsFixed(2)}).',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    // Respectful limit: max 500 expenses per trip
    // Only enforce on creation, not on editing
    final expensesAsync = ref.read(tripExpensesProvider(widget.tripId));
    final currentExpenseCount = expensesAsync.value?.length ?? 0;
    if (widget.expenseToEdit == null && currentExpenseCount >= 500) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'To keep things fast and easy to manage, a trip can have up to 500 expenses.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text);

      // Get exchange rate
      final currencyService = ref.read(currencyServiceProvider);
      final rateToBase = await currencyService.getRate(
        from: expenseCurrency,
        to: baseCurrency,
      );

      // Calculate shares
      final splitMeta = <String, double>{};
      final shares = <ExpenseShare>[];

      if (_splitType == SplitType.equal) {
        final shareAmount = (amount * rateToBase) / participants.length;
        for (var participant in participants) {
          splitMeta[participant.id] = 1.0;
          shares.add(
            ExpenseShare(
              participantId: participant.id,
              amountInBase: shareAmount,
            ),
          );
        }
      } else {
        // Calculate based on split type
        final totalBase = amount * rateToBase;

        // Collect split values and calculate shares
        for (var participant in participants) {
          final controller = _shareControllers[participant.id];
          final value = double.tryParse(controller?.text ?? '') ?? 0;
          splitMeta[participant.id] = value;

          double shareAmount;
          if (_splitType == SplitType.percentage) {
            shareAmount = (totalBase * value) / 100;
          } else {
            // Exact amount
            shareAmount = value;
          }

          shares.add(
            ExpenseShare(
              participantId: participant.id,
              amountInBase: shareAmount,
            ),
          );
        }
      }

      // Build participant name snapshots for inactive participant display
      Participant? payerParticipant;
      try {
        payerParticipant = participants.firstWhere(
          (p) => p.id == _selectedPayerId,
        );
      } catch (e) {
        // Payer not found, continue without snapshot
      }
      final payerDisplayName = payerParticipant?.displayName;

      final shareParticipantNames = <String, String>{};
      for (var participant in participants) {
        shareParticipantNames[participant.id] = participant.displayName;
      }

      // Create expense
      final expense = Expense(
        id: widget.expenseToEdit?.id ?? '',
        tripId: widget.tripId,
        payerId: _selectedPayerId!,
        description: _descriptionController.text.trim(),
        amount: amount,
        expenseCurrency: expenseCurrency,
        rateToBase: rateToBase,
        date: _selectedDate,
        splitType: _splitType,
        splitMeta: splitMeta,
        shares: shares,
        category: _selectedCategory!,
        receiptUrl: widget.expenseToEdit?.receiptUrl,
        payerDisplayName: payerDisplayName,
        shareParticipantNames: shareParticipantNames,
      );

      final repo = ref.read(expenseRepoProvider);
      if (widget.expenseToEdit != null) {
        // Update existing expense
        repo.updateExpense(expense);
      } else {
        // Add new expense
        repo.addExpense(expense);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expenseToEdit != null
                  ? 'Expense updated successfully'
                  : 'Expense added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add expense: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

// Custom formatter for percentage input (0-100, max 2 decimals)
class _PercentageInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty
    if (text.isEmpty) {
      return newValue;
    }

    // Only allow digits and one decimal point
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return oldValue;
    }

    // Check decimal places (max 2)
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length > 2 || parts[1].length > 2) {
        return oldValue;
      }
    }

    // Parse and check range (0-100)
    final value = double.tryParse(text);
    if (value != null && value > 100) {
      return oldValue;
    }

    return newValue;
  }
}

// Formatter for exact split money amounts (digits, single dot, max 2 decimals, no signs)
class _MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty to let user clear input
    if (text.isEmpty) {
      return newValue;
    }

    // Only digits and a single decimal point
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return oldValue;
    }

    // Disallow multiple dots
    if (text.indexOf('.') != text.lastIndexOf('.')) {
      return oldValue;
    }

    // Enforce max 2 decimals
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length > 2 || parts[1].length > 2) {
        return oldValue;
      }
    }

    return newValue;
  }
}

// Formatter for the main amount field (digits, single dot, max 2 decimals, enforce upper limit, no signs/scientific)
class _AmountInputFormatter extends TextInputFormatter {
  final double max;
  const _AmountInputFormatter({required this.max});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow empty to let user clear input
    if (text.isEmpty) {
      return newValue;
    }

    // Only digits and a single decimal point
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return oldValue;
    }

    // Disallow multiple dots
    if (text.indexOf('.') != text.lastIndexOf('.')) {
      return oldValue;
    }

    // Enforce max 2 decimals
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length > 2 || parts[1].length > 2) {
        return oldValue;
      }
    }

    // Prevent exceeding max
    final value = double.tryParse(text);
    if (value != null && value > max) {
      return oldValue;
    }

    return newValue;
  }
}
