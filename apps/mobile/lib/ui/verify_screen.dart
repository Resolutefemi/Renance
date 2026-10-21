/// The confirmation stop: right after a manual signup, or when a login
/// is blocked because the signup email was never confirmed (founder
/// directive 2026-09-30 - the account is locked until the emailed code
/// is entered; closing the app or reloading never loses the state, it
/// lives in the database). FOUNDER DIRECTIVE 2026-10-05: confirmation is
/// a 6-DIGIT CODE typed into this screen - no mailed link, no deep-link
/// hop, the app unlocks itself the moment the right code lands. The
/// screen offers the resend and the wrong-email rescue, still polls /me
/// on resume (a code typed on the website unlocks the app too), and
/// after verification the one-time appearance popup fires BEFORE the
/// desk opens (founder directive 2026-10-05: "the appearance settings
/// should only pop up after a user is done verifying his email").
/// Google signups are pre-verified and never see this screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        FilteringTextInputFormatter,
        LengthLimitingTextInputFormatter,
        TextInputFormatter;
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'appearance_sheet.dart' show maybeShowFirstAppearanceSheet;
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _sent = false;
  String? _error;
  // The signup address the confirmation code went to (passed as the
  // route argument from the register/login screens; may be empty for
  // older sessions, then /me fills it in).
  String? _signupEmail;
  // The 6-digit code the student types in.
  final TextEditingController _codeCtrl = TextEditingController();
  // Wrong-email rescue: swap the mistaken signup address for the correct
  // one. The API removes the old address and re-mails the code.
  bool _changing = false;
  bool _changed = false;
  final TextEditingController _emailCtrl = TextEditingController();
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The route argument may arrive slightly after initState on some
    // devices; _loadEmail also runs from didChangeDependencies.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.contains('@')) {
      _signupEmail = args;
    } else if (_signupEmail == null) {
      // Older sessions (deep-link relaunch) carry no argument: ask /me.
      _loadEmailFromMe();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The code can also be typed on the website; if the student verified
    // there and switches back, the app unlocks itself on resume.
    if (state == AppLifecycleState.resumed) {
      _checkConfirmed();
    }
  }

  Future<void> _loadEmailFromMe() async {
    try {
      final ApiClient api = context.read<ApiClient>();
      final MeResult me = await api.me();
      if (!mounted) return;
      setState(() {
        if (me.email.isNotEmpty) _signupEmail = me.email;
        // Already confirmed (the link landed earlier): unlock now.
        if (me.entitlement?.emailVerified ?? false) {
          _unlock();
        }
      });
    } on ApiException {
      // Offline or the restricted surface hiccuped: the card still
      // works - resend only needs the cooldown minute.
    } on NetworkException {
      // Offline: same.
    }
  }

  Future<void> _checkConfirmed() async {
    if (_unlocking) return;
    try {
      final ApiClient api = context.read<ApiClient>();
      final MeResult me = await api.me();
      if (!mounted) return;
      if (me.entitlement?.emailVerified ?? false) {
        await _unlock();
      }
    } on ApiException {
      // Still unconfirmed (or the surface refused): stay on the card.
    } on NetworkException {
      // Offline: stay on the card.
    }
  }

  /// The code landed (or was consumed on the web): swap the restricted
  /// session for a seated one, fire the one-time appearance popup (the
  /// founder gates it to AFTER verification) and open the desk.
  Future<void> _unlock() async {
    if (_unlocking || !mounted) return;
    _unlocking = true;
    setState(() => _busy = true);
    try {
      final ApiClient api = context.read<ApiClient>();
      final SessionStore session = context.read<SessionStore>();
      final AuthTokens fresh = await api.refreshSession();
      await session.save(fresh.token, fresh.user);
      if (!mounted) return;
      // Founder directive 2026-10-05: the appearance settings pop up
      // only after the email is verified - this is that moment.
      await maybeShowFirstAppearanceSheet(context);
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed('/home');
      return;
    } on ApiException catch (e) {
      // Confirmed but the refresh refused (rare): a plain re-login
      // mints the seated session anyway.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Your email is confirmed - sign in once more to open the desk. ($e)';
      });
      _unlocking = false;
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      _unlocking = false;
    }
  }

  /// Types the mailed 6-digit code in and consumes it. Wrong or expired
  /// codes surface the server's message; success unlocks the desk.
  Future<void> _verify() async {
    final String code = _codeCtrl.text.trim();
    if (RegExp(r'^\d{6}$').hasMatch(code) == false) {
      setState(() => _error = 'Enter the 6-digit code from your mail.');
      return;
    }
    if (_busy) return;
    final ApiClient api = context.read<ApiClient>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.verifyEmail(code);
      if (!mounted) return;
      await _unlock();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
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
        _signupEmail = email;
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
                Container(alignment: Alignment.center,
                  
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.surfaceContainer,
                  ),
                  child: MsIcon('mark_email_unread',
                      size: 30, color: context.ink),
                ),
                const SizedBox(height: 20),
                Text(
                  'Confirm your email',
                  textAlign: TextAlign.center,
                  style: RenanceText.sectionTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  _signupEmail == null
                      ? 'We sent a 6-digit confirmation code to your '
                          'inbox. Your account stays locked until you '
                          'type it in below.'
                      : 'We sent a 6-digit confirmation code to '
                          '$_signupEmail. Type it below to unlock your '
                          'account - it works once and expires in 24 '
                          'hours.',
                  textAlign: TextAlign.center,
                  style: RenanceText.bodySecondary.copyWith(
                    height: 1.5,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                // The code entry: one numeric field, digits spaced so it
                // reads like the mail's big code block. Enter submits.
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    filled: true,
                    fillColor: context.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 14),
                TactileButton(
                  onPressed: _busy ? null : _verify,
                  height: 52,
                  radius: BorderRadius.circular(10),
                  face: context.ink,
                  onFace: context.onInverseChip,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm my email'),
                ),
                const SizedBox(height: 12),
                // Spam-folder hint (founder directive 2026-10-02): the
                // sending domain is new, so Gmail/Outlook may file the
                // Renance mail under spam at first - telling students
                // where to look saves the signup.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Don't see it? Check your spam folder - open the "
                    "mail and mark it 'Not spam' so Renance lands in "
                    "your main inbox next time.",
                    textAlign: TextAlign.center,
                    style: RenanceText.bodySecondary.copyWith(
                      fontSize: 12.5,
                      height: 1.45,
                      color: context.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                TactileButton(
                  onPressed: _busy ? null : _resend,
                  height: 52,
                  radius: BorderRadius.circular(10),
                  face: context.ink,
                  onFace: context.onInverseChip,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _sent
                              ? 'Code sent, check the inbox'
                              : 'Resend the code',
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
                    'the confirmation code now goes to the new one.',
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
                    TactileButton(
                      onPressed: _busy ? null : _changeEmail,
                      height: 52,
                      radius: BorderRadius.circular(10),
                      face: context.ink,
                      onFace: context.onInverseChip,
                      child: const Text('Save and send the code there'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
