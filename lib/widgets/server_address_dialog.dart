import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'popup_title.dart';

/// Lets the user point the app at the CRM server (e.g. the Mac's current IP)
/// without rebuilding. Pops with `true` once an address is saved or reset.
class ServerAddressDialog extends StatefulWidget {
  const ServerAddressDialog({super.key});

  @override
  State<ServerAddressDialog> createState() => _ServerAddressDialogState();
}

class _ServerAddressDialogState extends State<ServerAddressDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: ApiService.baseUrl.replaceFirst(RegExp(r'/mobile_api$'), ''),
  );
  bool _busy = false;
  String? _result;
  bool _ok = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = ApiService.normalizeServerUrl(_controller.text);
    if (url == null) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    final error = await ApiService.testServer(url);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = error == null;
      _result = error ?? 'Connected';
    });
  }

  Future<void> _save() async {
    await ApiService.setServerUrl(_controller.text);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    await ApiService.setServerUrl('');
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const PopupTitle('Server address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => setState(() => _result = null),
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: '192.168.0.197:8080',
            ),
          ),
          const SizedBox(height: 8),
          if (_result != null)
            Text(_result!, style: TextStyle(color: _ok ? Colors.green.shade700 : Colors.red.shade700)),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : _reset, child: const Text('Reset')),
        TextButton(
          onPressed: _busy ? null : _test,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Test'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
