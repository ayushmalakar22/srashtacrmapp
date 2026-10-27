import 'package:flutter/material.dart';
import '../widgets/compact_search_field.dart';
import '../widgets/form_section.dart';
import '../widgets/popup_title.dart';
import '../services/api_service.dart';
import '../widgets/searchable_select_field.dart';
import 'add_contact_screen.dart';

class AddCustomerScreen extends StatefulWidget {
  final String? customerId;
  final bool readOnly;
  const AddCustomerScreen({super.key, this.customerId, this.readOnly = false});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  TabController? _tabController;
  bool _isLoading = true;
  bool _isSaving = false;

  // Lookup Data
  List<dynamic> _groups = [];
  List<dynamic> _currencies = [];
  List<dynamic> _languages = [];
  List<dynamic> _countries = [];
  List<dynamic> _staff = [];

  // Customer Admins
  List<dynamic> _customerAdmins = [];
  bool _isLoadingAdmins = false;
  String _adminSearchQuery = '';

  // Selections
  List<String> _selectedGroups = [];
  String? _selectedCurrency;
  String? _selectedLanguage;
  String? _selectedCountry;

  // Customer Details Controllers
  final _companyController = TextEditingController();
  final _vatController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();

  // Billing Controllers
  final _billingStreetController = TextEditingController();
  final _billingCityController = TextEditingController();
  final _billingStateController = TextEditingController();
  final _billingZipController = TextEditingController();
  String? _billingCountry;

  // Shipping Controllers
  final _shippingStreetController = TextEditingController();
  final _shippingCityController = TextEditingController();
  final _shippingStateController = TextEditingController();
  final _shippingZipController = TextEditingController();
  String? _shippingCountry;

  bool _isLoadingCustomer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.customerId != null ? 2 : 1, vsync: this);
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        setState(() {}); // Rebuild to hide/show bottom nav bar
      }
    });

    _fetchFormData();
    _fetchStaff();
    if (widget.customerId != null) {
      _fetchCustomerDetails();
      _fetchCustomerAdmins();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchStaff() async {
    try {
      final response = await ApiService.getStaff();
      if (response['status'] == true) {
        setState(() {
          _staff = response['data'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchCustomerAdmins() async {
    setState(() => _isLoadingAdmins = true);
    try {
      final response = await ApiService.getCustomerAdmins(widget.customerId!);
      if (response['status'] == true) {
        setState(() {
          _customerAdmins = response['data'] ?? [];
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingAdmins = false);
    }
  }

  Future<void> _fetchCustomerDetails() async {
    setState(() => _isLoadingCustomer = true);
    try {
      final response = await ApiService.getCustomer(widget.customerId!);
      if (response['status'] == true) {
        final data = response['data'];
        setState(() {
          _companyController.text = data['company'] ?? '';
          _vatController.text = data['vat'] ?? '';
          _phoneController.text = data['phonenumber'] ?? '';
          _websiteController.text = data['website'] ?? '';
          _addressController.text = data['address'] ?? '';
          _cityController.text = data['city'] ?? '';
          _stateController.text = data['state'] ?? '';
          _zipController.text = data['zip'] ?? '';
          
          if (data['country'] != null && data['country'].toString().isNotEmpty && data['country'] != '0') {
            _selectedCountry = data['country'].toString();
          }
          if (data['default_currency'] != null && data['default_currency'].toString().isNotEmpty && data['default_currency'] != '0') {
            _selectedCurrency = data['default_currency'].toString();
          }
          if (data['default_language'] != null && data['default_language'].toString().isNotEmpty) {
            _selectedLanguage = data['default_language'];
          }

          _billingStreetController.text = data['billing_street'] ?? '';
          _billingCityController.text = data['billing_city'] ?? '';
          _billingStateController.text = data['billing_state'] ?? '';
          _billingZipController.text = data['billing_zip'] ?? '';
          if (data['billing_country'] != null && data['billing_country'].toString().isNotEmpty && data['billing_country'] != '0') {
            _billingCountry = data['billing_country'].toString();
          }

          _shippingStreetController.text = data['shipping_street'] ?? '';
          _shippingCityController.text = data['shipping_city'] ?? '';
          _shippingStateController.text = data['shipping_state'] ?? '';
          _shippingZipController.text = data['shipping_zip'] ?? '';
          if (data['shipping_country'] != null && data['shipping_country'].toString().isNotEmpty && data['shipping_country'] != '0') {
            _shippingCountry = data['shipping_country'].toString();
          }

          if (data['groups'] != null) {
            _selectedGroups = (data['groups'] as List).map((g) => g['groupid'].toString()).toList();
          }
        });
      }
    } finally {
      setState(() => _isLoadingCustomer = false);
    }
  }

  Future<void> _fetchFormData() async {
    try {
      final response = await ApiService.getCustomerFormData();
      if (response['status'] == true) {
        setState(() {
          _groups = response['data']['groups'] ?? [];
          _currencies = response['data']['currencies'] ?? [];
          _languages = response['data']['languages'] ?? [];
          _countries = response['data']['countries'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load form data')),
        );
      }
    }
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(labelText: label);
  }

  Future<void> _saveCustomer(bool createContact) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final address = _addressController.text.trim();
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();
      final zip = _zipController.text.trim();

      // If the billing address wasn't filled in under "More Options", default it
      // to the main address so invoices always have a Bill To address instead
      // of showing blank (matches the main address unless explicitly overridden).
      final billingStreet = _billingStreetController.text.trim();
      final billingCity = _billingCityController.text.trim();
      final billingState = _billingStateController.text.trim();
      final billingZip = _billingZipController.text.trim();
      final billingHasOverride = billingStreet.isNotEmpty || billingCity.isNotEmpty ||
          billingState.isNotEmpty || billingZip.isNotEmpty || _billingCountry != null;

      final data = {
        'company': _companyController.text.trim(),
        'vat': _vatController.text.trim(),
        'phonenumber': _phoneController.text.trim(),
        'website': _websiteController.text.trim(),
        'address': address,
        'city': city,
        'state': state,
        'zip': zip,
        'country': _selectedCountry,
        'default_language': _selectedLanguage,
        'default_currency': _selectedCurrency,
        'groups_in': _selectedGroups,
        // Billing (falls back to the main address when left blank)
        'billing_street': billingHasOverride ? billingStreet : address,
        'billing_city': billingHasOverride ? billingCity : city,
        'billing_state': billingHasOverride ? billingState : state,
        'billing_zip': billingHasOverride ? billingZip : zip,
        'billing_country': billingHasOverride ? _billingCountry : _selectedCountry,
        // Shipping
        'shipping_street': _shippingStreetController.text.trim(),
        'shipping_city': _shippingCityController.text.trim(),
        'shipping_state': _shippingStateController.text.trim(),
        'shipping_zip': _shippingZipController.text.trim(),
        'shipping_country': _shippingCountry,
      };

      if (widget.customerId != null) {
        data['id'] = widget.customerId;
      }

      final response = widget.customerId == null 
        ? await ApiService.addCustomer(data)
        : await ApiService.updateCustomer(data);
        
      if (response['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.customerId == null ? 'Customer added successfully' : 'Customer updated successfully')),
          );
          if (createContact && response['data'] != null && response['data']['customer_id'] != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AddContactScreen(customerId: response['data']['customer_id'].toString()),
              ),
            );
          } else {
            Navigator.pop(context, true); // Return true to signal refresh
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Failed to add customer')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _copyBillingToShipping() {
    setState(() {
      _shippingStreetController.text = _billingStreetController.text;
      _shippingCityController.text = _billingCityController.text;
      _shippingStateController.text = _billingStateController.text;
      _shippingZipController.text = _billingZipController.text;
      _shippingCountry = _billingCountry;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Billing Address copied to Shipping!'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _showMultiSelectDialog(String title, List<dynamic> items, List<String> selectedValues, Function(List<String>) onConfirm) async {
    List<String> tempSelected = List.from(selectedValues);
    String query = '';
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final q = query.trim().toLowerCase();
            final visible = items.where((item) => item['name'].toString().toLowerCase().contains(q)).toList();
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              title: PopupTitle(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CompactSearchField(onChanged: (v) => setStateDialog(() => query = v)),
                    const SizedBox(height: 4),
                    Flexible(
                      child: visible.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text('No results', style: TextStyle(color: Colors.grey)),
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: visible.map((item) {
                                final itemId = item['id'].toString();
                                return CheckboxListTile(
                                  dense: true,
                                  visualDensity: const VisualDensity(vertical: -2),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(item['name']),
                                  value: tempSelected.contains(itemId),
                                  onChanged: (bool? checked) {
                                    setStateDialog(() {
                                      if (checked == true) {
                                        tempSelected.add(itemId);
                                      } else {
                                        tempSelected.remove(itemId);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onConfirm(tempSelected);
                    Navigator.pop(context);
                  },
                  child: Text(tempSelected.isEmpty ? 'Confirm' : 'Confirm (${tempSelected.length})'),
                ),
              ],
            );
          }
        );
      }
    );
  }
  Future<void> _showAddGroupDialog() async {
    final nameController = TextEditingController();
    bool isSavingGroup = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const PopupTitle('Add New Customer Group'),
              content: TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '* Name',
                ),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: isSavingGroup ? null : () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: isSavingGroup 
                    ? null 
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        setStateDialog(() => isSavingGroup = true);
                        try {
                          final response = await ApiService.addCustomerGroup(name);
                          if (response['status'] == true) {
                            final newGroup = response['data'];
                            setState(() {
                              _groups.add(newGroup);
                              _selectedGroups.add(newGroup['id'].toString());
                            });
                            if (mounted) Navigator.pop(context);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(response['message'] ?? 'Failed to add group')),
                              );
                            }
                            setStateDialog(() => isSavingGroup = false);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error adding group')),
                            );
                          }
                          setStateDialog(() => isSavingGroup = false);
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSavingGroup 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                      : const Text('Save'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCustomer) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final hasAdminsTab = widget.customerId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerId == null ? 'Add New Customer' : (widget.readOnly ? 'View Customer' : 'Edit Customer')),
        bottom: hasAdminsTab
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Details'),
                  Tab(text: 'Customer Admins'),
                ],
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
              )
            : null,
      ),
      bottomNavigationBar: widget.readOnly || (hasAdminsTab && _tabController?.index == 1)
          ? const SizedBox.shrink()
          : BottomAppBar(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                if (widget.customerId == null) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isSaving || _isLoading ? null : () => _saveCustomer(false),
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving || _isLoading ? null : () => _saveCustomer(true),
                      child: const Text('Save and create contact'),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving || _isLoading ? null : () => _saveCustomer(false),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: hasAdminsTab
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCustomerDetailsTab(),
                          _buildAdminsTab(),
                        ],
                      )
                    : _buildCustomerDetailsTab(),
              ),
    );
  }

  Widget _buildCustomerDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormSection(
            index: 0,
            title: 'Basic Info',
            icon: Icons.business_outlined,
            children: [
          TextFormField(
            controller: _companyController,
            decoration: _inputDecor('Company *'),
            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.text,
            decoration: _inputDecor('Phone'),
          ),
            ],
          ),
          FormSection(
            index: 1,
            title: 'Address',
            icon: Icons.location_on_outlined,
            children: [
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: _inputDecor('Address'),
          ),
          TextFormField(
            controller: _cityController,
            decoration: _inputDecor('City'),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: _inputDecor('State'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _zipController,
                  decoration: _inputDecor('Zip Code'),
                ),
              ),
            ],
          ),
          SearchableSelectField(
            label: 'Country',
            decoration: _inputDecor('Country'),
            options: _countries.map<SelectOption>((c) => SelectOption(c['country_id'].toString(), c['short_name'].toString())).toList(),
            value: _selectedCountry,
            onChanged: (val) => setState(() => _selectedCountry = val),
          ),
            ],
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: Colors.white,
              collapsedBackgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE6E8EC))),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE6E8EC))),
              title: Text('More Options', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vatController,
                  decoration: _inputDecor('VAT Number'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                  decoration: _inputDecor('Website'),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          _showMultiSelectDialog('Select Groups', _groups, _selectedGroups, (newSelection) {
                            setState(() => _selectedGroups = newSelection);
                          });
                        },
                        child: InputDecorator(
                          decoration: _inputDecor('Groups').copyWith(
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            _selectedGroups.isEmpty
                              ? 'Nothing selected'
                              : _groups.where((g) => _selectedGroups.contains(g['id'].toString())).map((g) => g['name']).join(', '),
                            style: TextStyle(color: _selectedGroups.isEmpty ? Colors.grey : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _showAddGroupDialog,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(11), // Adjust to match field height
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SearchableSelectField(
                  label: 'Currency',
                  decoration: _inputDecor('Currency'),
                  options: _currencies.map<SelectOption>((c) => SelectOption(c['id'].toString(), '${c['name']} (${c['symbol']})')).toList(),
                  value: _selectedCurrency,
                  onChanged: (val) => setState(() => _selectedCurrency = val),
                ),
                const SizedBox(height: 16),

                SearchableSelectField(
                  label: 'Default Language',
                  decoration: _inputDecor('Default Language'),
                  options: _languages.map<SelectOption>((l) => SelectOption(l.toString(), l.toString())).toList(),
                  value: _selectedLanguage,
                  onChanged: (val) => setState(() => _selectedLanguage = val),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Billing/shipping address is filled in automatically from the address above unless you override it here.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                _buildBillingShippingFields(),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBillingShippingFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          const Text('Billing Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const Divider(),
          const SizedBox(height: 8),
          TextFormField(
            controller: _billingStreetController,
            maxLines: 2,
            decoration: _inputDecor('Street'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _billingCityController,
            decoration: _inputDecor('City'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _billingStateController,
                  decoration: _inputDecor('State'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _billingZipController,
                  decoration: _inputDecor('Zip Code'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SearchableSelectField(
            label: 'Country',
            decoration: _inputDecor('Country'),
            options: _countries.map<SelectOption>((c) => SelectOption(c['country_id'].toString(), c['short_name'].toString())).toList(),
            value: _billingCountry,
            onChanged: (val) => setState(() => _billingCountry = val),
          ),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shipping Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              TextButton.icon(
                onPressed: _copyBillingToShipping,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Billing'),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          TextFormField(
            controller: _shippingStreetController,
            maxLines: 2,
            decoration: _inputDecor('Street'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _shippingCityController,
            decoration: _inputDecor('City'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _shippingStateController,
                  decoration: _inputDecor('State'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _shippingZipController,
                  decoration: _inputDecor('Zip Code'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SearchableSelectField(
            label: 'Country',
            decoration: _inputDecor('Country'),
            options: _countries.map<SelectOption>((c) => SelectOption(c['country_id'].toString(), c['short_name'].toString())).toList(),
            value: _shippingCountry,
            onChanged: (val) => setState(() => _shippingCountry = val),
          ),
      ],
    );
  }

  Widget _buildAdminsTab() {
    final filteredAdmins = _customerAdmins.where((admin) {
      final name = (admin['full_name'] ?? '').toString().toLowerCase();
      return name.contains(_adminSearchQuery.toLowerCase());
    }).toList();

    return _isLoadingAdmins
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: _inputDecor('Search Admins...').copyWith(
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _adminSearchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _handleAssignAdmins,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Assign'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredAdmins.isEmpty
                    ? const Center(child: Text('No admins found.'))
                    : ListView.separated(
                        itemCount: filteredAdmins.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final admin = filteredAdmins[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(admin['full_name'] != null && admin['full_name'].toString().isNotEmpty ? admin['full_name'][0].toUpperCase() : 'U'),
                            ),
                            title: Text(admin['full_name'] ?? 'Unknown'),
                            subtitle: Text('Assigned on: ${admin['date_assigned'] ?? ''}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeAdmin(admin['staff_id'].toString()),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
  }

  Future<void> _removeAdmin(String staffIdToRemove) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Admin'),
        content: const Text('Are you sure you want to remove this admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoadingAdmins = true);
    try {
      final List<String> currentAdminIds = _customerAdmins.map((e) => e['staff_id'].toString()).toList();
      currentAdminIds.remove(staffIdToRemove);

      final response = await ApiService.assignCustomerAdmins(widget.customerId!, currentAdminIds);
      if (response['status'] == true) {
        _fetchCustomerAdmins(); // Refresh list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin removed successfully')));
        }
      }
    } catch (e) {
      setState(() => _isLoadingAdmins = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove admin')));
      }
    }
  }

  Future<void> _handleAssignAdmins() async {
    final List<String> currentAdminIds = _customerAdmins.map((e) => e['staff_id'].toString()).toList();
    
    // Convert staff to items for multi-select
    final items = _staff.map((s) => {'id': s['staffid'].toString(), 'name': '${s['firstname']} ${s['lastname']}'}).toList();

    await _showMultiSelectDialog(
      'Assign Admin',
      items,
      currentAdminIds,
      (selectedIds) async {
        setState(() => _isLoadingAdmins = true);
        try {
          final response = await ApiService.assignCustomerAdmins(widget.customerId!, selectedIds);
          if (response['status'] == true) {
            _fetchCustomerAdmins(); // Refresh
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admins assigned successfully')));
            }
          }
        } catch (e) {
          setState(() => _isLoadingAdmins = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to assign admins')));
          }
        }
      },
    );
  }
}
