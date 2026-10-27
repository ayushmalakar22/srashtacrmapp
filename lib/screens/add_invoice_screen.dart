import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/form_section.dart';
import '../widgets/popup_title.dart';
import '../widgets/searchable_select_field.dart';

class AddInvoiceScreen extends StatefulWidget {
  final String? invoiceId;
  const AddInvoiceScreen({super.key, this.invoiceId});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Form Data
  List<dynamic> _customers = [];
  List<dynamic> _currencies = [];
  List<dynamic> _paymentModes = [];
  List<dynamic> _taxes = [];
  List<dynamic> _staff = [];
  List<dynamic> _availableItems = [];
  List<dynamic> _countries = [];

  // Selections & Controllers
  String? _selectedCustomer;
  String? _selectedCurrency;
  String? _selectedSaleAgent;
  // Not exposed in the UI (no "Discount Type" selector) - 'before_tax' is
  // the sensible default if staff types a discount amount in the totals row.
  String? _selectedDiscountType = 'before_tax';
  List<String> _selectedPaymentModes = [];
  String _recurring = '0'; // 0 = No, 1 = 1 month, etc.

  String _invoicePrefix = 'INV-';
  
  final _invoiceNumberController = TextEditingController();
  final _invoiceDateController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _adminNoteController = TextEditingController();
  final _clientNoteController = TextEditingController();
  final _termsController = TextEditingController();

  final _discountController = TextEditingController(text: '0');
  String _discountSymbol = '%';
  final _adjustmentController = TextEditingController(text: '0');

  bool _cancelOverdueReminders = false;
  final _cyclesController = TextEditingController(text: '0');
  bool _infinityCycles = true;

  // Address Details
  String? _billingStreet;
  String? _billingCity;
  String? _billingState;
  String? _billingZip;
  String? _billingCountry;

  String? _shippingStreet;
  String? _shippingCity;
  String? _shippingState;
  String? _shippingZip;
  String? _shippingCountry;

  bool _includeShipping = false;
  bool _showShippingOnInvoice = false;
  String _showQuantityAs = '1';

  // Items
  List<Map<String, dynamic>> _invoiceItems = [];
  List<String> _removedItems = [];
  
  // Staging Item Row
  String? _stagingSelectedItemId;
  final _stagingDescCtrl = TextEditingController();
  final _stagingLongDescCtrl = TextEditingController();
  final _stagingQtyCtrl = TextEditingController(text: '1');
  final _stagingRateCtrl = TextEditingController(text: '0');
  final _stagingUnitCtrl = TextEditingController();
  List<String> _stagingTaxes = [];

  @override
  void initState() {
    super.initState();
    _invoiceDateController.text = DateTime.now().toString().split(' ')[0];
    
    // Default Due Date (1 month from now)
    _dueDateController.text = DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0];
    
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final formDataResponse = await ApiService.getInvoiceFormData();
      if (formDataResponse['status'] == true) {
        final data = formDataResponse['data'];
        _customers = data['customers'] ?? [];
        _currencies = data['currencies'] ?? [];
        _paymentModes = data['payment_modes'] ?? [];
        _taxes = data['taxes'] ?? [];
        _staff = data['staff'] ?? [];
        _availableItems = data['items'] ?? [];
        _countries = data['countries'] ?? [];

        if (_currencies.isNotEmpty) {
          _selectedCurrency = _currencies.firstWhere((c) => c['isdefault'] == '1', orElse: () => _currencies[0])['id'].toString();
        }

        if (widget.invoiceId == null) {
          _invoicePrefix = data['invoice_prefix']?.toString() ?? 'INV-';
          final nextNum = data['next_invoice_number']?.toString() ?? '1';
          _invoiceNumberController.text = nextNum.padLeft(6, '0');
          
          final loggedInStaff = data['logged_in_staff_id']?.toString();
          if (loggedInStaff != null && _staff.any((s) => s['staffid'].toString() == loggedInStaff)) {
            _selectedSaleAgent = loggedInStaff;
          }
        }
      }

      if (widget.invoiceId != null) {
        final invoiceResponse = await ApiService.getInvoice(widget.invoiceId!);
        if (invoiceResponse['status'] == true) {
          _populateInvoiceData(invoiceResponse['data']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load data')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateInvoiceData(Map<String, dynamic> invoice) {
    _selectedCustomer = invoice['clientid']?.toString();
    _selectedCurrency = invoice['currency']?.toString();
    _selectedSaleAgent = invoice['sale_agent'] != '0' ? invoice['sale_agent']?.toString() : null;
    _selectedDiscountType = invoice['discount_type']?.toString();
    _recurring = invoice['custom_recurring'] != '0' ? 'custom' : (invoice['recurring']?.toString() ?? '0');
    if (invoice['recurring'] == '0' && invoice['custom_recurring'] == '0') _recurring = '0';
    else if (invoice['custom_recurring'] == '1') _recurring = 'custom';
    else _recurring = invoice['recurring']?.toString() ?? '0';
    
    _invoicePrefix = invoice['prefix']?.toString() ?? 'INV-';
    _invoiceNumberController.text = invoice['number']?.toString() ?? '';
    _invoiceDateController.text = invoice['date']?.toString() ?? '';
    _dueDateController.text = invoice['duedate']?.toString() ?? '';
    _adminNoteController.text = invoice['adminnote']?.toString() ?? '';
    _clientNoteController.text = invoice['clientnote']?.toString() ?? '';
    _termsController.text = invoice['terms']?.toString() ?? '';
    
    _discountController.text = invoice['discount_percent']?.toString() != '0.00' && invoice['discount_percent']?.toString() != '0'
        ? (invoice['discount_percent']?.toString() ?? '0')
        : (invoice['discount_total']?.toString() ?? '0');
    _discountSymbol = invoice['discount_percent']?.toString() != '0.00' && invoice['discount_percent']?.toString() != '0' ? '%' : 'Fixed Amount';
    if (_discountController.text == '0.00' || _discountController.text == '0') {
      _discountSymbol = '%';
    }
    _adjustmentController.text = invoice['adjustment']?.toString() ?? '0';

    _cancelOverdueReminders = invoice['cancel_overdue_reminders'] == '1';
    _cyclesController.text = invoice['cycles']?.toString() ?? '0';
    _infinityCycles = _cyclesController.text == '0';

    _billingStreet = invoice['billing_street']?.toString();
    _billingCity = invoice['billing_city']?.toString();
    _billingState = invoice['billing_state']?.toString();
    _billingZip = invoice['billing_zip']?.toString();
    _billingCountry = invoice['billing_country']?.toString();

    _includeShipping = invoice['include_shipping'] == '1';
    _showShippingOnInvoice = invoice['show_shipping_on_invoice'] == '1';
    _showQuantityAs = invoice['show_quantity_as']?.toString() ?? '1';

    _shippingStreet = invoice['shipping_street']?.toString();
    _shippingCity = invoice['shipping_city']?.toString();
    _shippingState = invoice['shipping_state']?.toString();
    _shippingZip = invoice['shipping_zip']?.toString();
    _shippingCountry = invoice['shipping_country']?.toString();

    if (invoice['allowed_payment_modes'] != null) {
      if (invoice['allowed_payment_modes'] is String) {
        _selectedPaymentModes = (invoice['allowed_payment_modes'] as String).split(',').where((e) => e.isNotEmpty).toList();
      } else if (invoice['allowed_payment_modes'] is List) {
         _selectedPaymentModes = List<String>.from(invoice['allowed_payment_modes']);
      }
    }

    if (invoice['items'] != null && invoice['items'] is List) {
      _invoiceItems = (invoice['items'] as List).map((item) {
        return {
          'id': item['id']?.toString(),
          'description': item['description']?.toString() ?? '',
          'long_description': item['long_description']?.toString() ?? '',
          'qty': double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0,
          'rate': double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0,
          'unit': item['unit']?.toString() ?? '',
          'taxname': item['taxname'] != null && item['taxname'] is List && item['taxname'].isNotEmpty ? item['taxname'] : [],
        };
      }).toList();
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toString().split(' ')[0];
      });
    }
  }

  List<dynamic> get _flatAvailableItems {
    List<dynamic> flat = [];
    for (var group in _availableItems) {
      if (group is List) {
        flat.addAll(group);
      } else if (group is Map) {
        if (group.containsKey('items') && group['items'] is List) {
          flat.addAll(group['items']);
        } else {
          flat.add(group);
        }
      }
    }
    return flat;
  }

  void _removeItem(int index) {
    setState(() {
      final item = _invoiceItems[index];
      if (item['id'] != null) {
        _removedItems.add(item['id'].toString());
      }
      _invoiceItems.removeAt(index);
    });
  }

  /// Add or edit a single invoice item in a bottom sheet instead of a
  /// permanently-visible form, so the main screen just shows the item list
  /// plus one "Add Item" button.
  void _openAddItemSheet({int? editIndex}) {
    if (editIndex != null) {
      final item = _invoiceItems[editIndex];
      _stagingDescCtrl.text = item['description']?.toString() ?? '';
      _stagingLongDescCtrl.text = item['long_description']?.toString() ?? '';
      _stagingQtyCtrl.text = (item['qty'] as double? ?? 1.0).toString();
      _stagingRateCtrl.text = (item['rate'] as double? ?? 0.0).toString();
      _stagingUnitCtrl.text = item['unit']?.toString() ?? '';
      _stagingTaxes
        ..clear()
        ..addAll(List<String>.from(item['taxname'] ?? []));
    } else {
      _stagingSelectedItemId = null;
      _stagingDescCtrl.clear();
      _stagingLongDescCtrl.clear();
      _stagingQtyCtrl.text = '1';
      _stagingRateCtrl.text = '0';
      _stagingUnitCtrl.clear();
      _stagingTaxes.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PopupTitle(editIndex == null ? 'Add Item' : 'Edit Item', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (_flatAvailableItems.isNotEmpty) ...[
                      SearchableSelectField(
                        label: 'Pick from catalog (optional)',
                        decoration: _inputDecor('Pick from catalog (optional)'),
                        value: null,
                        options: _flatAvailableItems.map<SelectOption>((item) {
                          final rateVal = item['rate'] != null ? double.tryParse(item['rate'].toString()) ?? 0.0 : 0.0;
                          return SelectOption(item['id'].toString(), '(${rateVal.toStringAsFixed(2)}) ${item['description']}');
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          final item = _flatAvailableItems.firstWhere((e) => e['id'].toString() == val);
                          setSheetState(() {
                            _stagingSelectedItemId = val;
                            _stagingDescCtrl.text = item['description']?.toString() ?? '';
                            _stagingLongDescCtrl.text = item['long_description']?.toString() ?? '';
                            _stagingRateCtrl.text = _getItemRate(item).toStringAsFixed(2);
                            _stagingUnitCtrl.text = item['unit']?.toString() ?? '';
                            _stagingTaxes.clear();
                            if (item['taxname'] != null && item['taxrate'] != null) {
                              _stagingTaxes.add('${item['taxname']}|${item['taxrate']}');
                            }
                            if (item['taxname_2'] != null && item['taxrate_2'] != null) {
                              _stagingTaxes.add('${item['taxname_2']}|${item['taxrate_2']}');
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(controller: _stagingDescCtrl, decoration: _inputDecor('Description')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stagingQtyCtrl,
                            decoration: _inputDecor('Qty'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setSheetState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _stagingRateCtrl,
                            decoration: _inputDecor('Rate'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: sheetContext,
                          builder: (dialogContext) {
                            return StatefulBuilder(
                              builder: (dialogContext, setDialogState) {
                                return AlertDialog(
                                  title: const PopupTitle('Select Taxes'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: _taxes.map((t) {
                                        final taxVal = '${t['name']}|${t['taxrate']}';
                                        return CheckboxListTile(
                                          dense: true,
                                          visualDensity: const VisualDensity(vertical: -2),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                          controlAffinity: ListTileControlAffinity.leading,
                                          title: Text('${t['name']} (${t['taxrate']}%)'),
                                          value: _stagingTaxes.contains(taxVal),
                                          onChanged: (val) {
                                            setDialogState(() {
                                              if (val == true) {
                                                _stagingTaxes.add(taxVal);
                                              } else {
                                                _stagingTaxes.remove(taxVal);
                                              }
                                            });
                                            setSheetState(() {});
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogContext),
                                      child: const Text('Done'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                      child: InputDecorator(
                        decoration: _inputDecor('Tax (optional)'),
                        child: Text(
                          _stagingTaxes.isEmpty
                              ? 'No Tax'
                              : _stagingTaxes.map((t) => '${t.split('|')[1]}%').join(', '),
                          style: TextStyle(
                            color: _stagingTaxes.isEmpty ? Colors.grey.shade700 : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount: $_currencySymbol${((double.tryParse(_stagingQtyCtrl.text) ?? 0.0) * (double.tryParse(_stagingRateCtrl.text) ?? 0.0)).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_stagingDescCtrl.text.trim().isEmpty && (double.tryParse(_stagingRateCtrl.text) ?? 0.0) == 0.0) {
                              return;
                            }
                            final newItem = {
                              'id': editIndex != null ? _invoiceItems[editIndex]['id'] : null,
                              'description': _stagingDescCtrl.text,
                              'long_description': _stagingLongDescCtrl.text,
                              'qty': double.tryParse(_stagingQtyCtrl.text) ?? 1.0,
                              'rate': double.tryParse(_stagingRateCtrl.text) ?? 0.0,
                              'unit': _stagingUnitCtrl.text,
                              'taxname': List<String>.from(_stagingTaxes),
                            };
                            setState(() {
                              if (editIndex != null) {
                                _invoiceItems[editIndex] = newItem;
                              } else {
                                _invoiceItems.add(newItem);
                              }
                            });
                            Navigator.pop(sheetContext);
                          },
                          icon: const Icon(Icons.check),
                          label: Text(editIndex == null ? 'Add to list' : 'Save changes'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onCustomerChanged(String? customerId) {
    setState(() {
      _selectedCustomer = customerId;
    });
    
    if (customerId == null) return;
    
    final customer = _customers.firstWhere((c) => c['userid'].toString() == customerId, orElse: () => null);
    if (customer != null) {
      setState(() {
        _billingStreet = customer['billing_street']?.toString();
        _billingCity = customer['billing_city']?.toString();
        _billingState = customer['billing_state']?.toString();
        _billingZip = customer['billing_zip']?.toString();
        _billingCountry = customer['billing_country']?.toString();

        _shippingStreet = customer['shipping_street']?.toString();
        _shippingCity = customer['shipping_city']?.toString();
        _shippingState = customer['shipping_state']?.toString();
        _shippingZip = customer['shipping_zip']?.toString();
        _shippingCountry = customer['shipping_country']?.toString();
        
        if (_shippingStreet != null && _shippingStreet!.isNotEmpty) {
          _includeShipping = true;
          _showShippingOnInvoice = true;
        }
        
        // Also update currency if customer has a default currency
        if (customer['default_currency'] != null && customer['default_currency'].toString() != '0') {
           _selectedCurrency = customer['default_currency'].toString();
        }
      });
    }
  }

  Future<void> _saveInvoice(bool asDraft) async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    setState(() => _isSaving = true);
    
    // Format newitems and items for perfex
    final Map<String, dynamic> newitems = {};
    final Map<String, dynamic> items = {};
    
    for (int i = 0; i < _invoiceItems.length; i++) {
      final item = _invoiceItems[i];
      final itemData = {
        'description': item['description'],
        'long_description': item['long_description'],
        'qty': item['qty'],
        'rate': item['rate'],
        'unit': item['unit'] ?? '',
        'taxname': item['taxname'], // Array of taxes if any
        'order': i + 1,
      };
      
      if (item['id'] != null) {
        itemData['itemid'] = item['id'];
        items[item['id'].toString()] = itemData;
      } else {
        newitems['$i'] = itemData;
      }
    }

    final data = {
      'clientid': _selectedCustomer,
      'number': _invoiceNumberController.text,
      'date': _invoiceDateController.text,
      'duedate': _dueDateController.text,
      'currency': _selectedCurrency,
      'allowed_payment_modes': _selectedPaymentModes,
      'sale_agent': _selectedSaleAgent,
      'discount_type': _selectedDiscountType ?? '',
      'adminnote': _adminNoteController.text,
      'clientnote': _clientNoteController.text,
      'terms': _termsController.text,
      'recurring': _recurring,
      'cancel_overdue_reminders': _cancelOverdueReminders ? '1' : '0',
      'cycles': _infinityCycles ? '0' : _cyclesController.text,
      'discount_percent': _discountSymbol == '%' ? _discountController.text : '0',
      'discount_total': _discountSymbol == 'Fixed Amount' ? _discountController.text : '0',
      'adjustment': _adjustmentController.text,
      'items': items,
      'newitems': newitems,
      'removed_items': _removedItems,
      if (widget.invoiceId == null && asDraft) 'save_as_draft': 'true',
      'billing_street': _billingStreet ?? '',
      'billing_city': _billingCity ?? '',
      'billing_state': _billingState ?? '',
      'billing_zip': _billingZip ?? '',
      'billing_country': _billingCountry ?? '',
      'include_shipping': _includeShipping ? '1' : '0',
      'show_shipping_on_invoice': _showShippingOnInvoice ? '1' : '0',
      'shipping_street': _shippingStreet ?? '',
      'shipping_city': _shippingCity ?? '',
      'shipping_state': _shippingState ?? '',
      'shipping_zip': _shippingZip ?? '',
      'shipping_country': _shippingCountry ?? '',
      'show_quantity_as': _showQuantityAs,
    };

    try {
      final response = widget.invoiceId == null
          ? await ApiService.addInvoice(data)
          : await ApiService.updateInvoice(widget.invoiceId!, data);
          
      if (response['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice saved successfully!')));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Error saving invoice')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving invoice: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(labelText: label);
  }

  // --- Calculations & Currency Helpers ---
  String get _currencySymbol {
    if (_selectedCurrency != null && _currencies.isNotEmpty) {
      final currency = _currencies.firstWhere(
        (c) => c['id'].toString() == _selectedCurrency,
        orElse: () => null,
      );
      if (currency != null && currency['symbol'] != null && currency['symbol'].toString().isNotEmpty) {
        return currency['symbol'].toString();
      }
    }
    return '\$';
  }

  double _getItemRate(Map<String, dynamic> item) {
    if (_selectedCurrency != null) {
      final currencyKey = 'rate_currency_$_selectedCurrency';
      if (item[currencyKey] != null &&
          item[currencyKey].toString().isNotEmpty &&
          item[currencyKey].toString() != '0' &&
          item[currencyKey].toString() != '0.00') {
        return double.tryParse(item[currencyKey].toString()) ?? 0.0;
      }
    }
    if (item['rate'] != null) {
      return double.tryParse(item['rate'].toString()) ?? 0.0;
    }
    return 0.0;
  }

  double get _subTotal {
    double total = 0;
    for (var item in _invoiceItems) {
      total += (item['qty'] as double) * (item['rate'] as double);
    }
    return total;
  }
  
  double get _totalTax {
    double totalTax = 0.0;
    for (var item in _invoiceItems) {
      final qty = (item['qty'] as double? ?? 1.0);
      final rate = (item['rate'] as double? ?? 0.0);
      final itemSubtotal = qty * rate;
      final taxes = item['taxname'];
      if (taxes is List) {
        for (var tax in taxes) {
          if (tax is String && tax.contains('|')) {
            final parts = tax.split('|');
            if (parts.length >= 2) {
              final ratePercent = double.tryParse(parts[1]) ?? 0.0;
              totalTax += (itemSubtotal * ratePercent) / 100.0;
            }
          }
        }
      }
    }
    return totalTax;
  }

  /// Per-tax breakdown (e.g. "CGST (9.00%)" -> amount), summed across all
  /// items, mirroring the CGST/SGST line items shown on the web admin panel.
  Map<String, double> get _taxBreakdown {
    final Map<String, double> breakdown = {};
    for (var item in _invoiceItems) {
      final qty = (item['qty'] as double? ?? 1.0);
      final rate = (item['rate'] as double? ?? 0.0);
      final itemSubtotal = qty * rate;
      final taxes = item['taxname'];
      if (taxes is List) {
        for (var tax in taxes) {
          if (tax is String && tax.contains('|')) {
            final parts = tax.split('|');
            if (parts.length >= 2) {
              final name = parts[0];
              final ratePercent = double.tryParse(parts[1]) ?? 0.0;
              final label = '$name (${ratePercent.toStringAsFixed(2)}%)';
              final amount = (itemSubtotal * ratePercent) / 100.0;
              breakdown[label] = (breakdown[label] ?? 0) + amount;
            }
          }
        }
      }
    }
    return breakdown;
  }

  double get _discountAmount {
    double discount = double.tryParse(_discountController.text) ?? 0;
    if (discount <= 0) return 0.0;

    double baseAmount = _subTotal;
    if (_selectedDiscountType == 'after_tax') {
      baseAmount = _subTotal + _totalTax;
    } else if (_selectedDiscountType != 'before_tax') {
      return 0.0;
    }

    if (_discountSymbol == '%') {
      return (baseAmount * discount) / 100.0;
    } else {
      return discount;
    }
  }

  double get _grandTotal {
    double adjustment = double.tryParse(_adjustmentController.text) ?? 0;
    return _subTotal + _totalTax - _discountAmount + adjustment;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoiceId == null ? 'Create New Invoice' : 'Edit Invoice'),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              if (widget.invoiceId == null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving || _isLoading ? null : () => _saveInvoice(true),
                    child: const Text('Save as Draft'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving || _isLoading ? null : () => _saveInvoice(false),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormSection(
                      index: 0,
                      title: 'Invoice Details',
                      icon: Icons.receipt_long_outlined,
                      children: [
                        SearchableSelectField(
                          label: 'Customer *',
                          decoration: _inputDecor('Customer *'),
                          options: _customers.map<SelectOption>((c) => SelectOption(c['userid'].toString(), c['company'].toString())).toList(),
                          value: _selectedCustomer,
                          onChanged: (val) => _onCustomerChanged(val),
                          validator: (value) => value == null ? 'Required' : null,
                        ),
                        // Address block slides open once a customer is picked.
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: _selectedCustomer == null
                              ? const SizedBox(width: double.infinity)
                              : Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F6FA),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: _buildAddressSection(),
                                ),
                        ),
                        // Only the fields staff actually need to enter day-to-day.
                        // Everything else (invoice number, currency, sale agent,
                        // recurring, discount type, payment modes, notes) already
                        // has a sensible default computed above/below and is sent
                        // to the backend as-is - no need to ask for it here. Those
                        // can still be changed later from the web admin panel.
                        TextFormField(
                          controller: _dueDateController,
                          readOnly: true,
                          decoration: _inputDecor('Due Date').copyWith(
                            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                          ),
                          onTap: () => _selectDate(_dueDateController),
                        ),
                      ],
                    ),
                    FormSection(
                      index: 1,
                      title: 'Items',
                      icon: Icons.list_alt_outlined,
                      trailing: _invoiceItems.isEmpty
                          ? null
                          : Text('${_invoiceItems.length} added', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_invoiceItems.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text('No items yet. Tap "Add Item" below.', style: TextStyle(color: Colors.grey.shade600)),
                                ),
                              // Tap a row to edit it
                              for (var index = 0; index < _invoiceItems.length; index++)
                                Builder(builder: (context) {
                                  final item = _invoiceItems[index];
                                  final qty = item['qty'] as double;
                                  final rate = item['rate'] as double;
                                  final total = qty * rate;
                                  // Material (not a coloured Container) so ListTile's
                                  // ink/background paints on the right surface.
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Material(
                                      color: const Color(0xFFF4F6FA),
                                      borderRadius: BorderRadius.circular(12),
                                      clipBehavior: Clip.antiAlias,
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: const EdgeInsets.only(left: 12, right: 4),
                                        onTap: () => _openAddItemSheet(editIndex: index),
                                        title: Text(item['description']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: Text('Qty: $qty x $_currencySymbol${rate.toStringAsFixed(2)} = $_currencySymbol${total.toStringAsFixed(2)}'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _removeItem(index),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openAddItemSheet(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    FormSection(
                      index: 2,
                      title: 'Summary',
                      icon: Icons.calculate_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _discountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDecor('Discount'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                decoration: _inputDecor('Type'),
                                isExpanded: true,
                                value: _discountSymbol,
                                items: const [
                                  DropdownMenuItem(value: '%', child: Text('%')),
                                  DropdownMenuItem(value: 'Fixed Amount', child: Text('Fixed Amount')),
                                ],
                                onChanged: (val) => setState(() => _discountSymbol = val ?? '%'),
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: _adjustmentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: _inputDecor('Adjustment'),
                          onChanged: (_) => setState(() {}),
                        ),
                        const Divider(height: 8),
                        _summaryRow('Sub Total', '$_currencySymbol${_subTotal.toStringAsFixed(2)}'),
                        ..._taxBreakdown.entries.map((tax) => _summaryRow(tax.key, '$_currencySymbol${tax.value.toStringAsFixed(2)}')),
                        _summaryRow('Discount', '-$_currencySymbol${_discountAmount.toStringAsFixed(2)}'),
                        _summaryRow('Adjustment', '$_currencySymbol${(double.tryParse(_adjustmentController.text) ?? 0).toStringAsFixed(2)}'),
                        const Divider(height: 8),
                        _summaryRow('Total', '$_currencySymbol${_grandTotal.toStringAsFixed(2)}', big: true),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _summaryRow(String label, String value, {bool big = false}) {
    final style = TextStyle(
      fontSize: big ? 18 : 14,
      fontWeight: big ? FontWeight.bold : FontWeight.w500,
      color: big ? Theme.of(context).colorScheme.primary : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  String _formatStr(String? val) {
    if (val == null || val.trim().isEmpty || val == '0') return '--';
    return val;
  }

  String _getCountryName(String? id) {
    if (id == null || id.trim().isEmpty || id == '0') return '--';
    try {
      final country = _countries.firstWhere((c) => c['country_id'].toString() == id);
      return '${country['short_name']} ${country['iso2']}';
    } catch (_) {
      return id;
    }
  }

  Widget _buildAddressSection() {
    if (_selectedCustomer == null) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  const Text('Bill To', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showAddressEditDialog(),
                    child: const Icon(Icons.edit_square, size: 16, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_formatStr(_billingStreet)),
              Text('${_formatStr(_billingCity)}, ${_formatStr(_billingState)}'),
              Text('${_formatStr(_billingZip)}, ${_getCountryName(_billingCountry)}'),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Ship to', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showAddressEditDialog(),
                    child: const Icon(Icons.edit_square, size: 16, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_formatStr(_shippingStreet)),
              Text('${_formatStr(_shippingCity)}, ${_formatStr(_shippingState)}'),
              Text('${_formatStr(_shippingZip)}, ${_getCountryName(_shippingCountry)}'),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddressEditDialog() {
    final billStreetCtrl = TextEditingController(text: _billingStreet);
    final billCityCtrl = TextEditingController(text: _billingCity);
    final billStateCtrl = TextEditingController(text: _billingState);
    final billZipCtrl = TextEditingController(text: _billingZip);
    String? tempBillCountry = _billingCountry;
    if (tempBillCountry == '0' || !_countries.any((c) => c['country_id'].toString() == tempBillCountry)) {
      tempBillCountry = null;
    }

    final shipStreetCtrl = TextEditingController(text: _shippingStreet);
    final shipCityCtrl = TextEditingController(text: _shippingCity);
    final shipStateCtrl = TextEditingController(text: _shippingState);
    final shipZipCtrl = TextEditingController(text: _shippingZip);
    String? tempShipCountry = _shippingCountry;
    if (tempShipCountry == '0' || !_countries.any((c) => c['country_id'].toString() == tempShipCountry)) {
      tempShipCountry = null;
    }

    bool tempIncludeShipping = _includeShipping;
    bool tempShowShipping = _showShippingOnInvoice;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const PopupTitle('Edit Address Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Billing Address', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(controller: billStreetCtrl, decoration: _inputDecor('Street'), maxLines: 2),
                  const SizedBox(height: 8),
                  TextFormField(controller: billCityCtrl, decoration: _inputDecor('City')),
                  const SizedBox(height: 8),
                  TextFormField(controller: billStateCtrl, decoration: _inputDecor('State')),
                  const SizedBox(height: 8),
                  TextFormField(controller: billZipCtrl, decoration: _inputDecor('Zip Code')),
                  const SizedBox(height: 8),
                  SearchableSelectField(
                    label: 'Country',
                    decoration: _inputDecor('Country'),
                    options: _countries.map<SelectOption>((c) => SelectOption(c['country_id'].toString(), c['short_name'].toString())).toList(),
                    value: tempBillCountry,
                    onChanged: (val) => setDialogState(() => tempBillCountry = val),
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  CheckboxListTile(
                    title: const Text('Shipping Address', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: tempIncludeShipping,
                    onChanged: (val) {
                      setDialogState(() {
                        tempIncludeShipping = val ?? false;
                        if (!tempIncludeShipping) {
                           tempShowShipping = false;
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (tempIncludeShipping)
                    CheckboxListTile(
                      title: const Text('Show shipping details in invoice'),
                      value: tempShowShipping,
                      onChanged: (val) => setDialogState(() => tempShowShipping = val ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                  if (tempIncludeShipping) ...[
                    const SizedBox(height: 8),
                    TextFormField(controller: shipStreetCtrl, decoration: _inputDecor('Street'), maxLines: 2),
                    const SizedBox(height: 8),
                    TextFormField(controller: shipCityCtrl, decoration: _inputDecor('City')),
                    const SizedBox(height: 8),
                    TextFormField(controller: shipStateCtrl, decoration: _inputDecor('State')),
                    const SizedBox(height: 8),
                    TextFormField(controller: shipZipCtrl, decoration: _inputDecor('Zip Code')),
                    const SizedBox(height: 8),
                    SearchableSelectField(
                    label: 'Country',
                    decoration: _inputDecor('Country'),
                    options: _countries.map<SelectOption>((c) => SelectOption(c['country_id'].toString(), c['short_name'].toString())).toList(),
                    value: tempShipCountry,
                    onChanged: (val) => setDialogState(() => tempShipCountry = val),
                  ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _billingStreet = billStreetCtrl.text;
                    _billingCity = billCityCtrl.text;
                    _billingState = billStateCtrl.text;
                    _billingZip = billZipCtrl.text;
                    _billingCountry = tempBillCountry;

                    _includeShipping = tempIncludeShipping;
                    _showShippingOnInvoice = tempShowShipping;

                    if (_includeShipping) {
                      _shippingStreet = shipStreetCtrl.text;
                      _shippingCity = shipCityCtrl.text;
                      _shippingState = shipStateCtrl.text;
                      _shippingZip = shipZipCtrl.text;
                      _shippingCountry = tempShipCountry;
                    } else {
                      _shippingStreet = '';
                      _shippingCity = '';
                      _shippingState = '';
                      _shippingZip = '';
                      _shippingCountry = '';
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

}
