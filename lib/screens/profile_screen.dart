import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/form_section.dart';
import '../widgets/popup_title.dart';
import '../widgets/staff_avatar.dart';

/// The logged in staff member's own details, like Profile in the admin panel:
/// name, email, phone, social links, email signature and password.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _fields = [
    'firstname',
    'lastname',
    'email',
    'phonenumber',
    'facebook',
    'linkedin',
    'skype',
    'email_signature',
  ];
  final _c = {for (final f in _fields) f: TextEditingController()};
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic>? _profile;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.getProfile();
      if (!mounted) return;
      if (res['status'] == true) {
        _fill(Map<String, dynamic>.from(res['data']));
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _error = res['message']?.toString() ?? 'Could not load your profile';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Cannot reach the server. Check Wi-Fi and try again.';
      });
    }
  }

  void _fill(Map<String, dynamic> p) {
    _profile = p;
    context.read<AuthProvider>().setAvatar((p['avatar_path'] ?? '').toString());
    for (final f in _fields) {
      _c[f]!.text = (p[f] ?? '').toString();
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final res = await ApiService.updateProfile(
          {for (final f in _fields) f: _c[f]!.text.trim()});
      if (!mounted) return;
      if (res['status'] == true) {
        _fill(Map<String, dynamic>.from(res['data']));
        context.read<AuthProvider>().setUserName(_profile!['name'].toString());
        setState(() => _saving = false);
        _toast('Profile updated');
      } else {
        setState(() => _saving = false);
        _toast(res['message']?.toString() ?? 'Could not update the profile');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Cannot reach the server. Check Wi-Fi and try again.');
    }
  }

  Future<void> _changePhoto() async {
    final hasPhoto = ((_profile?['avatar_path'] ?? '') as String).isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          if (hasPhoto)
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text('Remove photo',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      Map<String, dynamic> res;
      if (choice == 'remove') {
        res = await ApiService.removeProfileImage();
      } else {
        // shrunk on the phone first: a camera photo can be several MB
        final picked = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (picked == null) {
          if (mounted) setState(() => _photoBusy = false);
          return;
        }
        res = await ApiService.uploadProfileImage(picked.path);
      }
      if (!mounted) return;
      if (res['status'] == true) {
        final p = Map<String, dynamic>.from(res['data']);
        setState(
            () => _profile = {...?_profile, 'avatar_path': p['avatar_path']});
        context
            .read<AuthProvider>()
            .setAvatar((p['avatar_path'] ?? '').toString());
        _toast(choice == 'remove' ? 'Photo removed' : 'Photo updated');
      } else {
        _toast(res['message']?.toString() ?? 'Could not update the photo');
      }
    } catch (_) {
      if (mounted)
        _toast('Could not update the photo. Check Wi-Fi and try again.');
    }
    if (mounted) setState(() => _photoBusy = false);
  }

  Future<void> _changePassword() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (done == true && mounted) {
      _toast('Password changed. Other devices were signed out.');
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _field(String key, String label,
      {TextInputType? type,
      String? Function(String?)? validator,
      int maxLines = 1}) {
    return TextFormField(
      controller: _c[key],
      keyboardType: type,
      validator: validator,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 3 : 1,
      textCapitalization: key == 'firstname' || key == 'lastname'
          ? TextCapitalization.words
          : TextCapitalization.none,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.cloud_off_outlined,
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load)
              : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final p = _profile!;
    final cs = Theme.of(context).colorScheme;
    final name = (p['name'] ?? '').toString();
    final role = (p['role'] ?? '').toString();
    final lastLogin = (p['last_login'] ?? '').toString();
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Column(children: [
            GestureDetector(
              onTap: _photoBusy ? null : _changePhoto,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  StaffAvatar(
                      name: name,
                      path: (p['avatar_path'] ?? '').toString(),
                      radius: 44),
                  if (_photoBusy)
                    const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3)),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: cs.primary,
                      child: const Icon(Icons.photo_camera,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (role.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child:
                    Text(role, style: TextStyle(color: Colors.grey.shade700)),
              ),
            if (lastLogin.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Last login $lastLogin',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              ),
          ]),
          const SizedBox(height: 20),
          FormSection(
            index: 0,
            title: 'Personal details',
            icon: Icons.person_outline,
            children: [
              _field('firstname', 'First name *', validator: _required),
              _field('lastname', 'Last name *', validator: _required),
              _field('email', 'Email *',
                  type: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null),
              _field('phonenumber', 'Phone', type: TextInputType.phone),
            ],
          ),
          FormSection(
            index: 1,
            title: 'Social & signature',
            icon: Icons.link,
            children: [
              _field('facebook', 'Facebook', type: TextInputType.url),
              _field('linkedin', 'LinkedIn', type: TextInputType.url),
              _field('skype', 'Skype'),
              _field('email_signature', 'Email signature', maxLines: 4),
            ],
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: const Text('Save changes'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _changePassword,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Change password'),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _again = TextEditingController();
  bool _show = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String? error;
    if (_old.text.isEmpty) {
      error = 'Enter your current password';
    } else if (_new.text.length < 8) {
      error = 'New password must be at least 8 characters';
    } else if (_new.text != _again.text) {
      error = 'The two new passwords do not match';
    }
    if (error != null) return setState(() => _error = error);

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await ApiService.changePassword(_old.text, _new.text);
      if (!mounted) return;
      if (res['status'] == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _saving = false;
          _error =
              res['message']?.toString() ?? 'Could not change the password';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Cannot reach the server. Check Wi-Fi and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String label) => InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _show = !_show),
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PopupTitle('Change password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
                controller: _old,
                obscureText: !_show,
                decoration: dec('Current password')),
            const SizedBox(height: 12),
            TextField(
                controller: _new,
                obscureText: !_show,
                decoration: dec('New password')),
            const SizedBox(height: 12),
            TextField(
                controller: _again,
                obscureText: !_show,
                decoration: dec('Repeat new password')),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Change password'),
            ),
          ],
        ),
      ),
    );
  }
}
