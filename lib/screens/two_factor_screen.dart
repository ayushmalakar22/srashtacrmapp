import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Second step of signing in to an account with two factor authentication.
/// On success the session is open and this screen pops (the app switches to
/// the main screen by itself); when the code step has to be abandoned it pops
/// with a message for the login screen.
class TwoFactorScreen extends StatefulWidget {
  final String challenge;
  final String type; // 'email' or 'app'
  final String maskedEmail;

  const TwoFactorScreen({
    super.key,
    required this.challenge,
    required this.type,
    this.maskedEmail = '',
  });

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  static const _resendWait = 30;

  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  int _cooldown = _resendWait;
  Timer? _timer;

  bool get _isEmail => widget.type == 'email';

  @override
  void initState() {
    super.initState();
    if (_isEmail) _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendWait);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  /// The challenge ran out or the account got locked: back to the login screen.
  bool _isDead(String msg) =>
      msg.contains('expired') || msg.contains('Too many');

  Future<void> _verify() async {
    final code = _code.text.trim().toLowerCase();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the verification code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await context
        .read<AuthProvider>()
        .verifyTwoFactor(widget.challenge, code);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context); // the main screen is already behind us
      return;
    }
    final msg = res['message']?.toString() ?? 'Verification failed';
    if (_isDead(msg)) {
      Navigator.pop(context, msg);
      return;
    }
    setState(() {
      _busy = false;
      _error = msg;
    });
    _code.clear();
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    final res =
        await context.read<AuthProvider>().resendTwoFactor(widget.challenge);
    if (!mounted) return;
    final msg = res['message']?.toString() ?? '';
    if (res['success'] == true) {
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else if (_isDead(msg)) {
      Navigator.pop(context, msg);
    } else {
      setState(() => _error = msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                        _isEmail
                            ? Icons.mark_email_read_outlined
                            : Icons.verified_user_outlined,
                        size: 48,
                        color: cs.primary),
                    const SizedBox(height: 14),
                    Text('Two-step verification',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                        _isEmail
                            ? 'We emailed a verification code to ${widget.maskedEmail}.'
                            : 'Open your authenticator app and enter the 6-digit code for this account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 22),
                    Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: TextField(
                              controller: _code,
                              autofocus: true,
                              enabled: !_busy,
                              textAlign: TextAlign.center,
                              // emailed codes are hex + the staff id (letters too);
                              // authenticator codes are 6 digits
                              keyboardType: _isEmail
                                  ? TextInputType.text
                                  : TextInputType.number,
                              textCapitalization: TextCapitalization.none,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(
                                    _isEmail ? r'[0-9a-zA-Z]' : r'[0-9]')),
                                LengthLimitingTextInputFormatter(
                                    _isEmail ? 24 : 6),
                              ],
                              style: TextStyle(
                                  fontSize: 24,
                                  letterSpacing: _isEmail ? 2 : 6,
                                  fontWeight: FontWeight.w700),
                              onSubmitted: (_) => _busy ? null : _verify(),
                              decoration: InputDecoration(
                                labelText: 'Verification code',
                                errorText: _error,
                                errorMaxLines: 3,
                              ),
                            ))),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _verify,
                        child: _busy
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    color: cs.onPrimary, strokeWidth: 2))
                            : const Text('Verify'),
                      ),
                    ),
                    if (_isEmail) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy || _cooldown > 0 ? null : _resend,
                        child: Text(_cooldown > 0
                            ? 'Resend code in ${_cooldown}s'
                            : 'Resend code'),
                      ),
                    ],
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
