import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/form_section.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class AddContactScreen extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic>? contact;

  const AddContactScreen({super.key, required this.customerId, this.contact});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  XFile? _profileImage;
  final ImagePicker _picker = ImagePicker();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _titleController = TextEditingController(); // Position/Title
  final _passwordController = TextEditingController();

  String _direction = 'System Default';
  bool _isPrimary = false;
  bool _doNotSendWelcomeEmail = false;
  bool _sendSetPasswordEmail = false;

  // Permissions (IDs: 1=Invoices, 2=Estimates, 3=Contracts, 4=Proposals, 5=Support, 6=Projects)
  Map<int, bool> _permissions = {
    1: true,
    2: true,
    3: true,
    4: true,
    5: true,
    6: true,
  };

  // Email Notifications
  bool _invoiceEmails = true;
  bool _estimateEmails = true;
  bool _creditNoteEmails = true;
  bool _contractEmails = true;
  bool _taskEmails = true;
  bool _projectEmails = true;
  bool _ticketEmails = true;

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      final c = widget.contact!;
      _firstNameController.text = c['firstname'] ?? '';
      _lastNameController.text = c['lastname'] ?? '';
      _emailController.text = c['email'] ?? '';
      _phoneController.text = c['phonenumber'] ?? '';
      _titleController.text = c['title'] ?? '';
      
      if (c['direction'] == 'ltr') {
        _direction = 'LTR';
      } else if (c['direction'] == 'rtl') {
        _direction = 'RTL';
      }

      _isPrimary = c['is_primary'] == '1';
      
      // We don't prefill password for security

      // Handle permissions (In backend, we might not get permissions array directly, but let's try)
      // Usually permissions need a separate fetch, but if they are sent, we can parse them.

      // Email notifications
      _invoiceEmails = c['invoice_emails'] == '1';
      _estimateEmails = c['estimate_emails'] == '1';
      _creditNoteEmails = c['credit_note_emails'] == '1';
      _contractEmails = c['contract_emails'] == '1';
      _taskEmails = c['task_emails'] == '1';
      _projectEmails = c['project_emails'] == '1';
      _ticketEmails = c['ticket_emails'] == '1';
    }
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(labelText: label);
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> data = {
        'customer_id': widget.customerId,
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phonenumber': _phoneController.text.trim(),
        'title': _titleController.text.trim(),
        'direction': _direction == 'System Default' ? '' : (_direction == 'LTR' ? 'ltr' : 'rtl'),
      };

      if (_passwordController.text.isNotEmpty) {
        data['password'] = _passwordController.text;
      }

      if (widget.contact != null) {
        data['id'] = widget.contact!['id'].toString();
      }

      if (_isPrimary) data['is_primary'] = '1';
      if (_doNotSendWelcomeEmail) data['donotsendwelcomeemail'] = '1';
      if (_sendSetPasswordEmail) data['send_set_password_email'] = '1';

      // Permissions
      List<int> perms = [];
      _permissions.forEach((key, value) {
        if (value) perms.add(key);
      });
      data['permissions'] = perms;

      // Email notifications
      if (_invoiceEmails) data['invoice_emails'] = '1';
      if (_estimateEmails) data['estimate_emails'] = '1';
      if (_creditNoteEmails) data['credit_note_emails'] = '1';
      if (_contractEmails) data['contract_emails'] = '1';
      if (_taskEmails) data['task_emails'] = '1';
      if (_projectEmails) data['project_emails'] = '1';
      if (_ticketEmails) data['ticket_emails'] = '1';

      if (_profileImage != null) {
        data['profile_image_path'] = _profileImage!.path;
      }

      final response = widget.contact != null 
          ? await ApiService.updateContact(data)
          : await ApiService.addContact(data);
          
      if (response['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.contact != null ? 'Contact updated successfully!' : 'Contact created successfully!')),
          );
          Navigator.pop(context, true); // Return true to refresh/close
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Failed to create contact')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact != null ? 'Edit Contact' : 'Add Contact'),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveContact,
                  child: _isLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Contact'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _profileImage != null 
                          ? FileImage(File(_profileImage!.path)) 
                          : (widget.contact != null && widget.contact!['profile_image'] != null
                              ? NetworkImage(widget.contact!['profile_image'])
                              : null) as ImageProvider?,
                      child: _profileImage == null && (widget.contact == null || widget.contact!['profile_image'] == null)
                          ? const Icon(Icons.person, size: 40, color: Colors.grey) 
                          : null,
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setState(() {
                            _profileImage = image;
                          });
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Choose Profile Image'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FormSection(
                index: 0,
                title: 'Contact Info',
                icon: Icons.person_outline,
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecor('First Name *'),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _lastNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecor('Last Name *'),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecor('Email *'),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.text, // Changed from phone to text to fix emulator backspace bug
                    decoration: _inputDecor('Phone'),
                  ),
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecor('Position / Title'),
                  ),
                ],
              ),
              FormSection(
                index: 1,
                title: 'Account',
                icon: Icons.lock_outline,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: _inputDecor('Direction'),
                    value: _direction,
                    items: ['System Default', 'LTR', 'RTL'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setState(() => _direction = v!),
                  ),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _inputDecor('Password'),
                  ),
                  Column(
                    children: [
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Primary Contact'),
                        value: _isPrimary,
                        onChanged: (v) => setState(() => _isPrimary = v ?? false),
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Do not send welcome email'),
                        value: _doNotSendWelcomeEmail,
                        onChanged: (v) => setState(() => _doNotSendWelcomeEmail = v ?? false),
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Send SET password email'),
                        value: _sendSetPasswordEmail,
                        onChanged: (v) => setState(() => _sendSetPasswordEmail = v ?? false),
                      ),
                    ],
                  ),
                ],
              ),
              FormSection(
                index: 2,
                title: 'Permissions',
                icon: Icons.verified_user_outlined,
                gap: 0,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('Make sure to set appropriate permissions for this contact', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                  _buildPermissionSwitch('Invoices', 1),
                  _buildPermissionSwitch('Estimates', 2),
                  _buildPermissionSwitch('Contracts', 3),
                  _buildPermissionSwitch('Proposals', 4),
                  _buildPermissionSwitch('Support', 5),
                  _buildPermissionSwitch('Projects', 6),
                ],
              ),
              FormSection(
                index: 3,
                title: 'Email Notifications',
                icon: Icons.notifications_none,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 0,
                    children: [
                      _buildEmailSwitch('Invoice', _invoiceEmails, (v) => setState(() => _invoiceEmails = v)),
                      _buildEmailSwitch('Estimate', _estimateEmails, (v) => setState(() => _estimateEmails = v)),
                      _buildEmailSwitch('Credit Note', _creditNoteEmails, (v) => setState(() => _creditNoteEmails = v)),
                      _buildEmailSwitch('Project', _projectEmails, (v) => setState(() => _projectEmails = v)),
                      _buildEmailSwitch('Tickets', _ticketEmails, (v) => setState(() => _ticketEmails = v)),
                      _buildEmailSwitch('Contract', _contractEmails, (v) => setState(() => _contractEmails = v)),
                      _buildEmailSwitch('Task', _taskEmails, (v) => setState(() => _taskEmails = v)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionSwitch(String title, int id) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: _permissions[id] ?? false,
      onChanged: (val) {
        setState(() {
          _permissions[id] = val;
        });
      },
    );
  }

  Widget _buildEmailSwitch(String title, bool value, Function(bool) onChanged) {
    return SizedBox(
      width: 150,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
