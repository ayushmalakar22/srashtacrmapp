import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:srashtacrmapp/providers/auth_provider.dart';
import 'package:srashtacrmapp/screens/two_factor_screen.dart';

/// AuthProvider whose server calls are scripted, so only the screen is tested.
class _FakeAuth extends AuthProvider {
  final List<String> verified = [];
  int resent = 0;
  Map<String, dynamic> verifyAnswer = {'success': true};
  Map<String, dynamic> resendAnswer = {'success': true, 'message': 'sent'};

  @override
  Future<Map<String, dynamic>> verifyTwoFactor(
      String challenge, String code) async {
    verified.add('$challenge|$code');
    return verifyAnswer;
  }

  @override
  Future<Map<String, dynamic>> resendTwoFactor(String challenge) async {
    resent++;
    return resendAnswer;
  }
}

/// Opens the screen from a button, like the login screen does, and records
/// what it pops with.
Future<_FakeAuth> _open(WidgetTester t, {required String type}) async {
  final auth = _FakeAuth();
  await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final msg = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TwoFactorScreen(
                        challenge: 'CH', type: type, maskedEmail: 'n***@x.in'),
                  ),
                );
                if (msg != null && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('LOGIN:$msg')));
                }
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('go'));
  await t.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('authenticator: asks for the app code, digits only, max 6',
      (t) async {
    final auth = await _open(t, type: 'app');
    expect(find.textContaining('authenticator app'), findsOneWidget);
    expect(find.textContaining('Resend'), findsNothing);

    await t.enterText(find.byType(TextField), '12a34-5678');
    await t.pump();
    expect(
        find.text('123456'), findsOneWidget); // letters/dash dropped, cut at 6

    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
    expect(auth.verified, ['CH|123456']);
    expect(find.text('Two-step verification'), findsNothing); // popped
  });

  testWidgets(
      'wrong code: error under the field, stays on screen, field clears',
      (t) async {
    final auth = await _open(t, type: 'app');
    auth.verifyAnswer = {
      'success': false,
      'message': 'Invalid verification code'
    };

    await t.enterText(find.byType(TextField), '000000');
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();

    expect(find.text('Invalid verification code'), findsOneWidget);
    expect(find.text('Two-step verification'), findsOneWidget);
    expect(find.text('000000'), findsNothing);
  });

  testWidgets('empty code is not sent to the server', (t) async {
    final auth = await _open(t, type: 'app');
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
    expect(auth.verified, isEmpty);
    expect(find.text('Enter the verification code'), findsOneWidget);
  });

  testWidgets('expired / locked: goes back to login with the message',
      (t) async {
    final auth = await _open(t, type: 'app');
    auth.verifyAnswer = {
      'success': false,
      'message': 'Too many wrong codes. Try again in 15 minutes.'
    };
    await t.enterText(find.byType(TextField), '111111');
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();

    expect(find.text('Two-step verification'), findsNothing);
    expect(find.text('LOGIN:Too many wrong codes. Try again in 15 minutes.'),
        findsOneWidget);
  });

  testWidgets('email: shows masked address, accepts hex code, lower-cases it',
      (t) async {
    final auth = await _open(t, type: 'email');
    expect(find.textContaining('n***@x.in'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'A3F09C1B2');
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
    expect(auth.verified, ['CH|a3f09c1b2']);
  });

  testWidgets('email: resend is locked for 30s, then works', (t) async {
    final auth = await _open(t, type: 'email');
    expect(find.textContaining('Resend code in'), findsOneWidget);
    await t.tap(find.textContaining('Resend code in'));
    await t.pump();
    expect(auth.resent, 0);

    await t.pump(const Duration(seconds: 31));
    expect(find.text('Resend code'), findsOneWidget);
    await t.tap(find.text('Resend code'));
    await t.pump();
    expect(auth.resent, 1);
    expect(find.textContaining('Resend code in'),
        findsOneWidget); // cooldown again
    await t.pump(const Duration(seconds: 31));
  });

  testWidgets('back to sign in returns without a message', (t) async {
    await _open(t, type: 'app');
    await t.tap(find.text('Back to sign in'));
    await t.pumpAndSettle();
    expect(find.text('Two-step verification'), findsNothing);
    expect(find.textContaining('LOGIN:'), findsNothing);
  });
}
