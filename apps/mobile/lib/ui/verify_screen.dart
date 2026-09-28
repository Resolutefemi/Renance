/// The signup-only confirmation stop: right after a manual signup the
/// app shows this screen once so the student can resend the mail or
/// rescue a typo'd address - and SKIPPING is always fine, the desk
/// never blocks on confirmation and neither does signing in. Google
/// signups are pre-verified and never see this screen.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../storage.dart';
import 'theme.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  bool _busy = false;
  bool _sent = false;
  String? _error;
  // The signup address the confirmation mail went to (passed as the
  // route argument from the register screen; null for older sessions).
  String? _signupEmail;
  // Wrong-email rescue: swap the mistaken signup address for the correct
  // one. The API removes the old address and re-mails the confirmation.
  bool _changing = false;
  bool _changed = false;
  final TextEditingController _emailCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.contains('@')) _signupEmail = args;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_busy) return;
    final ApiClient api = context.read<ApiClient>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.resendVerification();
      if (!mounted) return;
      setState(() => _sent = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeEmail() async {
    if (_busy) return;
    final String email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter the correct email address');
      return;
    }
    final ApiClient api = context.read<ApiClient>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.changeEmail(email);
      if (!mounted) return;
      setState(() {
        _changed = true;
        _changing = false;
        _sent = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final SessionStore session = context.read<SessionStore>();
    await session.clear();
    if (!mounted) return;
    await SchoolController.forgetSchoolSession(session.prefs);
    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed('/login');
  }

  Future<void> _skip() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.surfaceContainer,
                  ),
                  child: Icon(Icons.mark_email_unread_outlined,
                      size: 30, color: context.ink),
                ),
                const SizedBox(height: 20),
                Text(
                  'Check your inbox',
                  textAlign: TextAlign.center,
                  style: RenanceText.sectionTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  _signupEmail == null
                      ? 'We sent a confirmation link to your inbox. Confirm '
                          'whenever you like - you can start studying right '
                          'away.'
                      : 'We sent a confirmation link to $_signupEmail. '
                          'Confirm whenever you like - you can start '
                          'studying right away.',
                  textAlign: TextAlign.center,
                  style: RenanceText.bodySecondary.copyWith(
                    height: 1.5,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.ink,
                      foregroundColor: context.onInverseChip,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _busy ? null : _resend,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _sent
                                ? 'Confirmation sent, check the inbox'
                                : 'Resend the confirmation mail',
                            style: RenanceText.bodyMedium.copyWith(
                              color: context.onInverseChip,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _busy ? null : _skip,
                    child: Text(
                      'Skip for now - start studying',
                      style: RenanceText.bodyMedium.copyWith(color: context.ink),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : _signOut,
                  child: Text(
                    'Sign out',
                    style: RenanceText.caption.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (_changed)
                  Text(
                    'Signup email changed - the old address was removed and '
                    'the confirmation link now goes to the new one.',
                    textAlign: TextAlign.center,
                    style: RenanceText.caption.copyWith(
                      color: context.textSecondary,
                    ),
                  )
                else ...<Widget>[
                  if (_changing) ...<Widget>[
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[AutofillHints.email],
                      decoration: InputDecoration(
                        hintText: 'The correct email address',
                        filled: true,
                        fillColor: context.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.ink,
                          foregroundColor: context.onInverseChip,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _busy ? null : _changeEmail,
                        child: Text(
                          'Save and send the link there',
                          style: RenanceText.bodyMedium.copyWith(
                            color: context.onInverseChip,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _changing = !_changing),
                    child: Text(
                      _changing
                          ? 'Keep the current email'
                          : 'Typed a wrong email at signup? Change it',
                      style: RenanceText.caption.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: RenanceText.caption.copyWith(color: context.error),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  _changed
                      ? 'Check the new inbox for the fresh link.'
                      : 'Wrong address? Change it above, or sign up again '
                          'from the login screen.',
                  textAlign: TextAlign.center,
                  style: RenanceText.caption.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
