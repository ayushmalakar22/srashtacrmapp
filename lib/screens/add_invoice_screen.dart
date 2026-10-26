import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
  String? _selectedDiscountType;
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

  void _showAddNewItemDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add New Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(decoration: _inputDecor('Description *')),
                const SizedBox(height: 8),
                TextFormField(decoration: _inputDecor('Long Description'), maxLines: 2),
                const SizedBox(height: 8),
                ..._currencies.map((c) {
                  final isBase = c['isdefault'] == '1';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextFormField(
                      decoration: _inputDecor('Rate - ${c['name']}${isBase ? ' (Base Currency)' : ''} *'),
                      keyboardType: TextInputType.number,
                    ),
                  );
                }).toList(),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: _inputDecor('Tax 1'),
                        items: _taxes.map((t) => DropdownMenuItem<String>(value: t['id'].toString(), child: Text('${t['name']} (${t['taxrate']}%)'))).toList()..insert(0, const DropdownMenuItem(value: '', child: Text('No Tax'))),
                        onChanged: (val) {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: _inputDecor('Tax 2'),
                        items: _taxes.map((t) => DropdownMenuItem<String>(value: t['id'].toString(), child: Text('${t['name']} (${t['taxrate']}%)'))).toList()..insert(0, const DropdownMenuItem(value: '', child: Text('No Tax'))),
                        onChanged: (val) {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(decoration: _inputDecor('Unit')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: _inputDecor('Item Group'),
                  items: _getUniqueGroups().map((g) {
                    return DropdownMenuItem<String>(value: g['id'].toString(), child: Text(g['name'].toString()));
                  }).toList()..insert(0, const DropdownMenuItem(value: '', child: Text('Nothing selected'))),
                  onChanged: (val) {},
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item saved to inventory (UI only)')));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, String>> _getUniqueGroups() {
    final Map<String, String> groups = {};
    for (var item in _flatAvailableItems) {
      if (item['group_id'] != null && item['group_id'].toString() != '0' && item['group_name'] != null) {
        groups[item['group_id'].toString()] = item['group_name'].toString();
      }
    }
    return groups.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
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
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.invoiceId == null) ...[
                OutlinedButton(
                  onPressed: _isSaving || _isLoading ? null : () => _saveInvoice(true),
                  child: const Text('Save as Draft'),
                ),
                const SizedBox(width: 12),
              ],
              ElevatedButton(
                onPressed: _isSaving || _isLoading ? null : () => _saveInvoice(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
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
                    // Customer
                    DropdownButtonFormField<String>(
                      decoration: _inputDecor('Customer *'),
                      isExpanded: true,
                      value: _selectedCustomer,
                      items: _customers.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem<String>(
                          value: c['userid'].toString(),
                          child: Text(c['company']),
                        );
                      }).toList(),
                      onChanged: (val) => _onCustomerChanged(val),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildAddressSection(),
                    const SizedBox(height: 16),
                    
                    // Dates
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _invoiceDateController,
                            readOnly: true,
                            decoration: _inputDecor('Invoice Date *').copyWith(
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                            onTap: () => _selectDate(_invoiceDateController),
                            validator: (value) => value!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _dueDateController,
                            readOnly: true,
                            decoration: _inputDecor('Due Date').copyWith(
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                            onTap: () => _selectDate(_dueDateController),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Currency is needed up front since item rates below are
                    // shown/entered in this currency; everything else that's
                    // optional or rarely changed lives in "More Options" so the
                    // common case (pick customer, add items, save) stays short.
                    DropdownButtonFormField<String>(
                      decoration: _inputDecor('Currency'),
                      isExpanded: true,
                      value: _selectedCurrency,
                      items: _currencies.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem<String>(
                          value: c['id'].toString(),
                          child: Text(c['name']),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCurrency = val),
                    ),
                    const SizedBox(height: 4),

                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        title: const Text('More Options', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                          'Invoice number, sale agent, recurring, discount type, notes...',
                          style: TextStyle(fontSize: 12),
                        ),
                        children: [
                          TextFormField(
                            controller: _invoiceNumberController,
                            decoration: _inputDecor('Invoice Number').copyWith(
                              prefixText: _invoicePrefix,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: const Text('Prevent sending overdue reminders for this invoice'),
                            value: _cancelOverdueReminders,
                            onChanged: (val) {
                              setState(() {
                                _cancelOverdueReminders = val ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _showPaymentModesDialog,
                            child: InputDecorator(
                              decoration: _inputDecor('Allowed payment modes for this invoice'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedPaymentModes.isEmpty
                                          ? 'Nothing selected'
                                          : _paymentModes
                                              .where((pm) => _selectedPaymentModes.contains(pm['id'].toString()))
                                              .map((pm) => pm['name'])
                                              .join(', '),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: _inputDecor('Sale Agent'),
                            isExpanded: true,
                            value: _selectedSaleAgent,
                            items: _staff.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem<String>(
                                value: s['staffid'].toString(),
                                child: Text('${s['firstname']} ${s['lastname']}'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedSaleAgent = val),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: _inputDecor('Recurring Invoice?'),
                            isExpanded: true,
                            value: _recurring,
                            items: [
                              const DropdownMenuItem(value: '0', child: Text('No')),
                              for (int i = 1; i <= 12; i++)
                                DropdownMenuItem(value: i.toString(), child: Text('$i Month(s)')),
                              const DropdownMenuItem(value: 'custom', child: Text('Custom')),
                            ],
                            onChanged: (val) => setState(() => _recurring = val ?? '0'),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: _inputDecor('Discount Type'),
                            isExpanded: true,
                            value: _selectedDiscountType,
                            items: const [
                              DropdownMenuItem(value: '', child: Text('No Discount')),
                              DropdownMenuItem(value: 'before_tax', child: Text('Before Tax')),
                              DropdownMenuItem(value: 'after_tax', child: Text('After Tax')),
                            ],
                            onChanged: (val) => setState(() => _selectedDiscountType = val),
                          ),
                          const SizedBox(height: 16),
                          if (_recurring != '0') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cyclesController,
                                    keyboardType: TextInputType.number,
                                    readOnly: _infinityCycles,
                                    decoration: _inputDecor('Total Cycles'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: _infinityCycles,
                                      onChanged: (val) {
                                        setState(() {
                                          _infinityCycles = val ?? true;
                                          if (_infinityCycles) {
                                            _cyclesController.text = '0';
                                          }
                                        });
                                      },
                                    ),
                                    const Text('Infinity'),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _adminNoteController,
                            decoration: _inputDecor('Admin Note'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _clientNoteController,
                            decoration: _inputDecor('Client Note'),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _termsController,
                            decoration: _inputDecor('Terms & Conditions'),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 0,
                      children: [
                        const Text('Show quantity as:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Radio<String>(value: '1', groupValue: _showQuantityAs, onChanged: (v) => setState(() => _showQuantityAs = v!), visualDensity: VisualDensity.compact),
                        const Text('Qty', style: TextStyle(fontSize: 12)),
                        Radio<String>(value: '2', groupValue: _showQuantityAs, onChanged: (v) => setState(() => _showQuantityAs = v!), visualDensity: VisualDensity.compact),
                        const Text('Hours', style: TextStyle(fontSize: 12)),
                        Radio<String>(value: '3', groupValue: _showQuantityAs, onChanged: (v) => setState(() => _showQuantityAs = v!), visualDensity: VisualDensity.compact),
                        const Text('Qty/Hours', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Add Item Dropdown, Bill Tasks & Add New Item button
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            decoration: _inputDecor('Add Item'),
                            isExpanded: true,
                            value: null,
                            items: _flatAvailableItems.map((item) {
                              final rateVal = item['rate'] != null ? double.tryParse(item['rate'].toString()) ?? 0.0 : 0.0;
                              return DropdownMenuItem<String>(
                                value: item['id'].toString(),
                                child: Text('(${rateVal.toStringAsFixed(2)}) ${item['description']}', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              final item = _flatAvailableItems.firstWhere((e) => e['id'].toString() == val);
                              setState(() {
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
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            decoration: _inputDecor('Bill Tasks'),
                            isExpanded: true,
                            value: '',
                            items: const [DropdownMenuItem(value: '', child: Text('No Tasks'))],
                            onChanged: null, // Placeholder since API doesn't return tasks yet
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
                          onPressed: _showAddNewItemDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Staging Row UI
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(controller: _stagingDescCtrl, decoration: _inputDecor('Description')),
                            const SizedBox(height: 8),
                            TextFormField(controller: _stagingLongDescCtrl, decoration: _inputDecor('Long Description')),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: _stagingQtyCtrl, 
                                    decoration: _inputDecor(_showQuantityAs == '2' ? 'Hours' : (_showQuantityAs == '3' ? 'Qty/Hours' : 'Qty')), 
                                    keyboardType: TextInputType.number,

                                    onChanged: (v) => setState((){}), // trigger amount update
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: _stagingRateCtrl, 
                                    decoration: _inputDecor('Rate'), 
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => setState((){}), // trigger amount update
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return StatefulBuilder(
                                            builder: (context, setStateDialog) {
                                              return AlertDialog(
                                                title: const Text('Select Taxes'),
                                                content: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: _taxes.map((t) {
                                                      final taxVal = '${t['name']}|${t['taxrate']}';
                                                      return CheckboxListTile(
                                                        title: Text('${t['name']} (${t['taxrate']}%)'),
                                                        value: _stagingTaxes.contains(taxVal),
                                                        onChanged: (val) {
                                                          setStateDialog(() {
                                                            if (val == true) {
                                                              _stagingTaxes.add(taxVal);
                                                            } else {
                                                              _stagingTaxes.remove(taxVal);
                                                            }
                                                          });
                                                          setState(() {});
                                                        },
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
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
                                      decoration: _inputDecor('Tax'),
                                      child: Text(
                                        _stagingTaxes.isEmpty
                                            ? 'No Tax'
                                            : _stagingTaxes.map((t) => '${t.split('|')[1]}%').join(', '),
                                        style: TextStyle(
                                          color: _stagingTaxes.isEmpty ? Colors.grey.shade700 : Colors.black87,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Text(
                                    'Amount: $_currencySymbol${((double.tryParse(_stagingQtyCtrl.text) ?? 0.0) * (double.tryParse(_stagingRateCtrl.text) ?? 0.0)).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (_stagingDescCtrl.text.trim().isEmpty && (double.tryParse(_stagingRateCtrl.text) ?? 0.0) == 0.0) {
                                      return;
                                    }
                                    setState(() {
                                      _invoiceItems.add({
                                        'description': _stagingDescCtrl.text,
                                        'long_description': _stagingLongDescCtrl.text,
                                        'qty': double.tryParse(_stagingQtyCtrl.text) ?? 1.0,
                                        'rate': double.tryParse(_stagingRateCtrl.text) ?? 0.0,
                                        'unit': _stagingUnitCtrl.text,
                                        'taxname': List<String>.from(_stagingTaxes),
                                      });
                                      // Clear staging
                                      _stagingSelectedItemId = null;
                                      _stagingDescCtrl.clear();
                                      _stagingLongDescCtrl.clear();
                                      _stagingQtyCtrl.text = '1';
                                      _stagingRateCtrl.text = '0';
                                      _stagingUnitCtrl.clear();
                                      _stagingTaxes.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.check),
                                  label: const Text('Add to list'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Items List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _invoiceItems.length,
                      itemBuilder: (context, index) {
                        final item = _invoiceItems[index];
                        final qty = item['qty'] as double;
                        final rate = item['rate'] as double;
                        final total = qty * rate;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(item['description']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${_showQuantityAs == '2' ? 'Hours' : (_showQuantityAs == '3' ? 'Qty/Hours' : 'Qty')}: $qty x $_currencySymbol${rate.toStringAsFixed(2)} = $_currencySymbol${total.toStringAsFixed(2)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeItem(index),
                            ),
                          ),
                        );
                      },
                    ),

                    const Divider(),
                    // Totals
                    Row(
                      children: [
                        const Expanded(child: Text('Sub Total:', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(width: 189),
                        SizedBox(width: 80, child: Text('$_currencySymbol${_subTotal.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Discount:', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            controller: _discountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 105,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), border: OutlineInputBorder()),
                            isExpanded: true,
                            value: _discountSymbol,
                            items: const [
                              DropdownMenuItem(value: '%', child: Text('%')),
                              DropdownMenuItem(value: 'Fixed Amount', child: Text('Fixed Amount', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) => setState(() => _discountSymbol = val ?? '%'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 80, child: Text('-$_currencySymbol${_discountAmount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._taxBreakdown.entries.map(
                      (tax) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text('${tax.key}:', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                            const SizedBox(width: 189),
                            SizedBox(width: 80, child: Text('$_currencySymbol${tax.value.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 16))),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(child: Text('Adjustment:', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            controller: _adjustmentController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 121),
                        SizedBox(width: 80, child: Text('$_currencySymbol${(double.tryParse(_adjustmentController.text) ?? 0).toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Text('Total:', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue))),
                        const SizedBox(width: 189),
                        SizedBox(width: 80, child: Text('$_currencySymbol${_grandTotal.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      ],
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
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
            title: const Text('Edit Address Details'),
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
                  DropdownButtonFormField<String>(
                    decoration: _inputDecor('Country'),
                    isExpanded: true,
                    value: tempBillCountry,
                    items: _countries.map<DropdownMenuItem<String>>((c) {
                      return DropdownMenuItem<String>(
                        value: c['country_id'].toString(),
                        child: Text(c['short_name']),
                      );
                    }).toList(),
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
                    DropdownButtonFormField<String>(
                      decoration: _inputDecor('Country'),
                      isExpanded: true,
                      value: tempShipCountry,
                      items: _countries.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem<String>(
                          value: c['country_id'].toString(),
                          child: Text(c['short_name']),
                        );
                      }).toList(),
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

  void _showPaymentModesDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Allowed Payment Modes'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _paymentModes.map((pm) {
                    final id = pm['id'].toString();
                    return CheckboxListTile(
                      title: Text(pm['name']),
                      value: _selectedPaymentModes.contains(id),
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            _selectedPaymentModes.add(id);
                          } else {
                            _selectedPaymentModes.remove(id);
                          }
                        });
                        setState(() {});
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
