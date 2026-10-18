/// Splash → route decision, plus the two credential screens.
///
/// Top of every credential screen: the FOR STUDENTS / FOR SCHOOLS
/// segmented switch. Students is the default - everything Renance has
/// ever shipped lives on that side - while schools opens the management
/// + teacher world: school sign-up (name + type), and staff sign-in that
/// lands straight in the school workspace (syllabus, scheme of work,
/// notes).
library;

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import '../config.dart';
import '../device_id.dart';
import '../models.dart';
import '../controllers.dart';
import '../storage.dart';
import 'appearance_sheet.dart';
import 'google_logo.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';

/// Shared scaffold for the credential screens (mockup layout: logo block,
/// audience switch, white card form, footer link).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.audience,
    required this.onAudienceChanged,
    required this.form,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final AuthAudience audience;
  final ValueChanged<AuthAudience> onAudienceChanged;
  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: <Widget>[
                RenanceMark(size: 72),
                SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                SegmentedButton<AuthAudience>(
                  segments: const <ButtonSegment<AuthAudience>>[
                    ButtonSegment<AuthAudience>(
                      value: AuthAudience.students,
                      icon: Icon(Icons.person_outline, size: 18),
                      label: Text('For Students'),
                    ),
                    ButtonSegment<AuthAudience>(
                      value: AuthAudience.schools,
                      icon: Icon(Icons.school_outlined, size: 18),
                      label: Text('For Schools'),
                    ),
                  ],
                  selected: <AuthAudience>{audience},
                  onSelectionChanged: (Set<AuthAudience> s) =>
                      onAudienceChanged(s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: form,
                  ),
                ),
                SizedBox(height: 24),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Which side of the house the credential screen is serving.
enum AuthAudience { students, schools }

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: context.textSecondary,
        ),
      ),
    );
  }
}

/// Shared password input. Signup uses two of them (password +
/// confirmation, founder directive 2026-10-03): the first advances the
/// keyboard into the confirmation, the second submits the form.
class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    this.onSubmitted,
    this.hint = 'at least 8 characters',
    this.textInputAction = TextInputAction.done,
    this.focusNode,
  });

  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final String hint;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: !_visible,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted == null
          ? null
          : (_) => widget.onSubmitted!(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
          ),
          onPressed: () => setState(() => _visible = !_visible),
        ),
        hintText: widget.hint,
      ),
    );
  }
}

/// Management's WhatsApp rescue line for the one-account-per-device lock
/// (founder directive 2026-10-02): a student who lost their phone or
/// bought a new device DMs this number, management verifies them and
/// clears the old binding server-side so the next login seats cleanly.
const String kManagementWhatsAppNumber = '+234 916 763 6685';
const String kManagementWhatsAppUrl =
    'https://wa.me/2349167636685?text='
    'Hello%20Renance%20management%2C%20I%20cannot%20sign%20in%20because%20'
    'my%20account%20is%20locked%20to%20my%20other%20device.%20I%20lost%20or%'
    '20changed%20my%20phone.%20Please%20move%20my%20account.%20My%20username%20is%3A%20';

/// Shows the one-account-per-device dialog when a sign-in was refused
/// with device_locked / device_taken. Returns true when the dialog was
/// shown (the caller skips the plain inline error - the dialog already
/// carries the full explanation).
///
/// Founder directive (2026-10-02): the DM-management rescue works ONLY
/// for the lost/replaced-phone case - device_locked, someone on a NEW
/// device tried to sign in with an account still bound to their OLD
/// device. That dialog carries the WhatsApp line and the DM button.
/// A device_taken refusal (this phone already owns a different account)
/// never points at management: it just says to sign in with the account
/// this device owns.
Future<bool> _maybeShowDeviceLockHelp(
  BuildContext context,
  String code,
  String message,
) async {
  if (code != 'device_locked' && code != 'device_taken') return false;
  if (!context.mounted) return true;
  if (code == 'device_taken') {
    // This device already owns another account - no management rescue,
    // no WhatsApp line. The fix is on the student's side: sign in with
    // the account that was created on this phone.
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: const Icon(Icons.devices_other_outlined, size: 32),
        title: const Text('This device owns an account'),
        content: const Text(
          'This phone is already signed up with a Renance account, and a '
          'device can only hold one. Sign in with the account that was '
          'created on this phone - use its username or email and '
          'password, or its Google account.',
          style: TextStyle(height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
    return true;
  }
  // device_locked: the account is bound to another device - this is the
  // lost/replaced-phone case, and management is the way through.
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      icon: const Icon(Icons.phonelink_lock_outlined, size: 32),
      title: const Text('One account, one device'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'This account is locked to your other device, so it cannot '
            'open here - even for you. Lost your phone or bought a new '
            'one? DM Renance management and we will move your account to '
            'this device.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            'WhatsApp: $kManagementWhatsAppNumber',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.support_agent_outlined, size: 20),
          label: const Text('DM management'),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            launchUrl(
              Uri.parse(kManagementWhatsAppUrl),
              mode: LaunchMode.externalApplication,
            ).catchError((Object _) => false);
          },
        ),
      ],
    ),
  );
  return true;
}

/// Google sign-in button, rendered only when GOOGLE_WEB_CLIENT_ID was
/// baked at build time, mirroring the web app's graceful degradation.
/// (Students only - school staff sign in with their school email.)
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const GoogleLogo(size: 18),
      label: const Text('Continue with Google'),
    );
  }
}

/// Runs the Google Identity Services flow and exchanges the ID token for a
/// Renance session. Returns false when the user cancelled the sheet.
Future<bool> _runGoogleSignIn(
  BuildContext context, {
  required void Function(String message) onError,
}) async {
  final ApiClient api = context.read<ApiClient>();
  final SessionStore session = context.read<SessionStore>();
  final GoogleSignInAccount? account =
      await GoogleSignIn(serverClientId: googleWebClientId).signIn();
  if (account == null) return false;
  final GoogleSignInAuthentication auth = await account.authentication;
  final String? idToken = auth.idToken;
  if (idToken == null) {
    onError('Google did not return an ID token, try again');
    return false;
  }
  // The device id rides the Google exchange too: the one-account-per-
  // device lock covers every sign-in path on the app (empty on web).
  final AuthTokens res = await api.authWithGoogle(
    idToken,
    deviceId: await DeviceId.get(),
  );
  await session.save(res.token, res.user);
  // First-time Google students ARE first-time signups (the upsert
  // creates the account) - the founder's appearance popup fires here
  // too, gated by the same one-time flag as the manual flows.
  if (!context.mounted) return true;
  await maybeShowFirstAppearanceSheet(context);
  if (!context.mounted) return true;
  await Navigator.of(context).pushReplacementNamed('/home');
  return true;
}

class LoginScreen extends StatefulWidget {
  // initialAudience (founder bugfix 2026-10-05): the footer hop from the
  // register screen, and every other route into this screen, now carries
  // the FOR STUDENTS / FOR SCHOOLS tab across - a school manager tapping
  // "Sign in" on the school sign-up page lands on the SCHOOL sign-in,
  // never back on the student form.
  const LoginScreen({super.key, this.initialAudience = AuthAudience.students});

  final AuthAudience initialAudience;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late AuthAudience _audience = widget.initialAudience;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ApiClient api = context.read<ApiClient>();
    final SessionStore session = context.read<SessionStore>();
    final SyncController sync = context.read<SyncController>();
    try {
      // Audience (founder directive 2026-10-02): school workplace
      // accounts and student accounts are separate. The server refuses
      // a student account under For Schools (and a school account under
      // For Students) before any session is seated.
      final AuthTokens res = await api.loginFull(
        _username.text.trim(),
        password: _password.text,
        deviceId: await DeviceId.get(),
        audience: _audience == AuthAudience.schools ? 'schools' : 'students',
      );
      await session.save(res.token, res.user);

      if (_audience == AuthAudience.schools) {
        // Route staff into the school workspace; verify membership first.
        final List<SchoolContextModel> contexts = await api.schoolMe();
        if (contexts.isEmpty) {
          if (!mounted) return;
          setState(() {
            _error =
                'This account is not linked to a school. Use For Students, or register your school first.';
            _busy = false;
          });
          return;
        }
        final SharedPreferences prefs = session.prefs;
        await SchoolController.rememberSchoolSession(prefs, contexts.first);
        if (!mounted) return;
        await Navigator.of(context).pushReplacementNamed('/school');
        return;
      }
      final SharedPreferences prefs = session.prefs;
      await SchoolController.forgetSchoolSession(prefs);
      if (!mounted) return;
      // Founder directive (2026-10-02, restored): the first login on a
      // device that never met the picker shows the appearance popup
      // once - students who signed up during the popup-less releases
      // still get to meet it.
      await maybeShowFirstAppearanceSheet(context);
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
      // Founder directive (2026-09-30): a login whose signup email was
      // never confirmed does not open the desk. The 403 body carries a
      // restricted session (drives resend + wrong-email rescue on the
      // verify screen) and the address the fresh confirmation mail went
      // to - park the student on the verify screen until the link is
      // consumed. Closing the app never loses the state: it lives in
      // the database, and the next login lands right back here.
      if (e.code == 'email_unverified' && e.body != null) {
        final String? token = e.body!['token'] as String?;
        final dynamic userRaw = e.body!['user'];
        if (token != null && token.isNotEmpty && userRaw is Map) {
          await session.save(
            token,
            AppUser.fromJson(userRaw.cast<String, dynamic>()),
          );
        }
        final dynamic verify = e.body!['emailVerification'];
        final String email = verify is Map
            ? ((verify['email'] ?? '') as String)
            : '';
        if (!mounted) return;
        // The appearance picker stays gated to AFTER verification (founder
        // directive 2026-10-05): this student is still unconfirmed, the
        // verify screen fires the popup once the code lands.
        await Navigator.of(context)
            .pushReplacementNamed('/verify', arguments: email);
        return;
      }
      // One account per device: the device-lock refusals get the
      // management-rescue dialog (WhatsApp DM), not the inline error.
      if (!mounted) return;
      if (await _maybeShowDeviceLockHelp(context, e.code, e.message)) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } on NetworkException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
    sync.refreshPendingCount().ignore();
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final SyncController sync = context.read<SyncController>();
    try {
      await _runGoogleSignIn(context, onError: (message) {
        if (mounted) setState(() => _error = message);
      });
    } on ApiException catch (e) {
      if (!mounted) {
        sync.refreshPendingCount().ignore();
        return;
      }
      if (await _maybeShowDeviceLockHelp(context, e.code, e.message)) {
        if (mounted) setState(() => _busy = false);
        sync.refreshPendingCount().ignore();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Google sign-in failed, try again');
    }
    if (mounted) setState(() => _busy = false);
    sync.refreshPendingCount().ignore();
  }

  /// Forgot password (founder directive 2026-10-02): the sheet takes the
  /// account email (or username), the API mails a single-use reset link,
  /// and the link opens the web reset page in any browser.
  void _openForgotPassword(BuildContext context, bool isSchool) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(isSchool: isSchool),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSchool = _audience == AuthAudience.schools;
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: isSchool
          ? 'Management and teachers sign in with the school email.'
          : 'Sign in to continue your streak.',
      audience: _audience,
      onAudienceChanged: (AuthAudience a) =>
          setState(() => _audience = a),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _FieldLabel(isSchool ? 'School email' : 'Username or email'),
          TextField(
            controller: _username,
            autocorrect: false,
            keyboardType: isSchool
                ? TextInputType.emailAddress
                : TextInputType.text,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              prefixIcon: Icon(
                isSchool ? Icons.alternate_email : Icons.person_outline,
                size: 20,
              ),
              hintText: isSchool ? 'school@yourdomain.com' : 'your username',
            ),
          ),
          SizedBox(height: 16),
          _FieldLabel('Password'),
          _PasswordField(controller: _password, onSubmitted: _submit),
          // Forgot password (founder directive 2026-10-02): works for
          // student and school accounts - the reset link mails to the
          // address on the account and opens the web reset page in any
          // browser, the phone's included.
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _busy
                  ? null
                  : () => _openForgotPassword(context, isSchool),
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (_error != null) ...<Widget>[
            SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(color: context.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          TactileButton(
            onPressed: _busy ? null : _submit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_busy)
                  const RenanceMark(size: 16, busy: true, onDark: true)
                else
                  const Icon(Icons.arrow_forward, size: 18),
                const SizedBox(width: 8),
                Text(
                  _busy
                      ? 'Signing in…'
                      : isSchool
                          ? 'Open school workspace'
                          : 'Sign In',
                ),
              ],
            ),
          ),
          if (!isSchool && googleWebClientId.isNotEmpty) ...<Widget>[
            SizedBox(height: 10),
            _GoogleButton(onPressed: _busy ? null : _signInWithGoogle),
          ],
        ],
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            "Don't have an account? ",
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pushReplacementNamed(
              '/register',
              // Carry the tab across (founder bugfix 2026-10-05): a
              // school sign-up started from the school sign-in stays on
              // the For Schools side.
              arguments: _audience,
            ),
            child: Text(
              'Sign up',
              style: TextStyle(
                color: context.ink,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  // initialAudience (founder bugfix 2026-10-05): the hop from the login
  // screen carries the FOR STUDENTS / FOR SCHOOLS tab across - "Sign up
  // for school" opens the SCHOOL sign-up form, not the student one.
  const RegisterScreen({
    super.key,
    this.initialAudience = AuthAudience.students,
  });

  final AuthAudience initialAudience;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late AuthAudience _audience = widget.initialAudience;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  // Confirmation password (founder directive 2026-10-03): the password
  // is typed twice - a mismatch never leaves the phone.
  final TextEditingController _confirmPassword = TextEditingController();
  final FocusNode _confirmFocus = FocusNode();
  // School sign-up fields.
  final TextEditingController _schoolName = TextEditingController();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  String _schoolType = 'secondary';
  bool _busy = false;
  String? _error;
  // Founder directive 2026-10-05: account creation is gated on the
  // terms + privacy consent - students and school sign-ups alike. The
  // box starts unchecked and the submit (and the Google hop) stay dead
  // until it is ticked; _submit re-checks as belt and braces.
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _confirmFocus.dispose();
    _schoolName.dispose();
    _fullName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    // Consent gate (founder directive 2026-10-05): no tick, no account.
    if (!_acceptedTerms) {
      setState(() {
        _error =
            'Accept the Terms of Service and Privacy Policy to continue.';
      });
      return;
    }
    // The pair must match before anything is sent (students and school
    // sign-ups share the two fields).
    if (_password.text != _confirmPassword.text) {
      setState(() {
        _error = 'Passwords do not match - type the same password twice.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ApiClient api = context.read<ApiClient>();
    final SessionStore session = context.read<SessionStore>();
    try {
      if (_audience == AuthAudience.schools) {
        if (_schoolName.text.trim().length < 3 ||
            _fullName.text.trim().length < 3) {
          setState(() {
            _error = 'Enter the school name and your full name.';
            _busy = false;
          });
          return;
        }
        final AuthTokens res = await api.schoolRegister(
          schoolName: _schoolName.text.trim(),
          schoolType: _schoolType,
          fullName: _fullName.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          // One device, one account covers school sign-ups too (founder
          // directive 2026-10-02) - dormant server-side until DEVICE_LOCK
          // is set to true, but the id always rides along so flipping the
          // switch needs no app update.
          deviceId: await DeviceId.get(),
        );
        await session.save(res.token, res.user);
        // Remember the workspace so the splash lands here next launch.
        final List<SchoolContextModel> contexts = await api.schoolMe();
        final SharedPreferences prefs = session.prefs;
        if (contexts.isNotEmpty) {
          await SchoolController.rememberSchoolSession(prefs, contexts.first);
        }
        if (!mounted) return;
        await Navigator.of(context).pushReplacementNamed('/school');
        return;
      }
      final String email = _email.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        setState(() {
          _error =
              'Enter your email address - the confirmation code goes there.';
          _busy = false;
        });
        return;
      }
      final AuthTokens res = await api.registerFull(
        _username.text.trim(),
        password: _password.text,
        email: email,
        deviceId: await DeviceId.get(),
      );
      await session.save(res.token, res.user);
      final SharedPreferences prefs = session.prefs;
      await SchoolController.forgetSchoolSession(prefs);
      if (!mounted) return;
      // Founder directive (2026-10-02, restored) - amended 2026-10-05:
      // the appearance popup now waits until the 6-digit email code is
      // VERIFIED (it fires from the verify screen's unlock, before the
      // desk opens), so a brand-new student never meets the picker
      // before their account is unlocked.
      // Founder directive (2026-09-30): the signup does NOT enter the
      // desk until the emailed 6-digit code is consumed - the session
      // the API returned is restricted to the confirmation surface. The
      // verify screen offers resend and the wrong-email rescue, takes
      // the code entry, polls /me on resume and unlocks the moment the
      // right code lands (appearance popup included, post-verification).
      await Navigator.of(context).pushReplacementNamed('/verify',
          arguments: email);
    } on ApiException catch (e) {
      // One account per device: registering on a device that already
      // owns an account gets the rescue dialog, not the inline error.
      if (!mounted) return;
      if (await _maybeShowDeviceLockHelp(context, e.code, e.message)) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } on NetworkException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  void _openPrivacyPolicy() {
    // The public policy page (same one the Play Store listing points
    // at); runs in any browser via the phone's handler of choice.
    launchUrl(
      Uri.parse('https://renance.app/privacy/'),
      mode: LaunchMode.externalApplication,
    ).catchError((Object _) => false);
  }

  Future<void> _signUpWithGoogle() async {
    if (_busy) return;
    // Consent gate rides the Google hop too (founder directive
    // 2026-10-05): no tick, no account, however the signup arrives.
    if (!_acceptedTerms) {
      setState(() {
        _error =
            'Accept the Terms of Service and Privacy Policy to continue.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _runGoogleSignIn(context, onError: (message) {
        if (mounted) setState(() => _error = message);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (await _maybeShowDeviceLockHelp(context, e.code, e.message)) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Google sign-in failed, try again');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isSchool = _audience == AuthAudience.schools;
    return AuthScaffold(
      title: isSchool ? 'Register your school' : 'Create your account',
      subtitle: isSchool
          ? 'Management + teacher accounts, syllabuses, notes and results.'
          : 'Under a minute - then pick how Renance looks.',
      audience: _audience,
      onAudienceChanged: (AuthAudience a) =>
          setState(() => _audience = a),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (isSchool) ...<Widget>[
            _FieldLabel('School name'),
            TextField(
              controller: _schoolName,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.school_outlined, size: 20),
                hintText: 'e.g. Living Grace Academy',
              ),
            ),
            SizedBox(height: 16),
            _FieldLabel('School type'),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'primary', label: Text('Primary')),
                ButtonSegment<String>(value: 'secondary', label: Text('Secondary')),
                ButtonSegment<String>(value: 'both', label: Text('Both')),
              ],
              selected: <String>{_schoolType},
              onSelectionChanged: (Set<String> s) =>
                  setState(() => _schoolType = s.first),
              showSelectedIcon: false,
            ),
            SizedBox(height: 16),
            _FieldLabel('Your full name (management)'),
            TextField(
              controller: _fullName,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge_outlined, size: 20),
                hintText: 'e.g. Mr Kelvin O.',
              ),
            ),
            SizedBox(height: 16),
            _FieldLabel('School email'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.alternate_email, size: 20),
                hintText: 'school@yourdomain.com',
              ),
            ),
            SizedBox(height: 16),
          ] else ...<Widget>[
            _FieldLabel('Username'),
            TextField(
              controller: _username,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline, size: 20),
                hintText: 'lowercase letters, digits, _',
              ),
            ),
            SizedBox(height: 16),
            _FieldLabel('Email'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const <String>[AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.alternate_email, size: 20),
                hintText: 'you@example.com',
              ),
            ),
            SizedBox(height: 16),
          ],
          _FieldLabel('Password'),
          _PasswordField(
            controller: _password,
            textInputAction: TextInputAction.next,
            onSubmitted: () => _confirmFocus.requestFocus(),
          ),
          SizedBox(height: 16),
          _FieldLabel('Confirm password'),
          _PasswordField(
            controller: _confirmPassword,
            hint: 'the same password again',
            focusNode: _confirmFocus,
            onSubmitted: _submit,
          ),
          SizedBox(height: 16),
          // Consent row (founder directive 2026-10-05): rides BOTH
          // signup forms, sits right above the submit so the disabled
          // button explains itself. Tapping the words toggles the box;
          // Privacy Policy opens the public policy page.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 22,
                width: 22,
                child: Checkbox(
                  value: _acceptedTerms,
                  onChanged: (bool? v) =>
                      setState(() => _acceptedTerms = v ?? false),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _acceptedTerms = !_acceptedTerms),
                  child: Text.rich(
                    TextSpan(
                      text:
                          'I accept the Terms of Service and ',
                      children: <InlineSpan>[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: _openPrivacyPolicy,
                            child: Text(
                              'Privacy Policy',
                              style: TextStyle(
                                color: context.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...<Widget>[
            SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(color: context.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          TactileButton(
            // Dead until the consent box is ticked (founder directive
            // 2026-10-05); _submit re-checks for belt and braces.
            onPressed: (_busy || !_acceptedTerms) ? null : _submit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_busy)
                  const RenanceMark(size: 16, busy: true, onDark: true)
                else
                  const Icon(Icons.arrow_forward, size: 18),
                const SizedBox(width: 8),
                Text(
                  _busy
                      ? 'Setting up…'
                      : isSchool
                          ? 'Create school workspace'
                          : 'Start studying',
                ),
              ],
            ),
          ),
          if (!isSchool && googleWebClientId.isNotEmpty) ...<Widget>[
            SizedBox(height: 10),
            _GoogleButton(onPressed: _busy ? null : _signUpWithGoogle),
          ],
          SizedBox(height: 10),
          Text(
            isSchool
                ? 'The full Nigerian curriculum - classes, subjects, term syllabuses with notes - is installed for you automatically.'
                : "We'll send a 6-digit confirmation code to your email, then ask about your school and exams right after.",
            textAlign: TextAlign.center,
            style: TextStyle(color: context.outline, fontSize: 12),
          ),
        ],
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Already studying with us? ',
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pushReplacementNamed(
              '/login',
              // Carry the tab across (founder bugfix 2026-10-05): the
              // school sign-up's "Sign in" opens the school sign-in.
              arguments: _audience,
            ),
            child: Text(
              'Sign in',
              style: TextStyle(
                color: context.ink,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Forgot password sheet (founder directive 2026-10-02): enter the
/// account email (or username) and a single-use reset link is mailed.
/// The link opens the Renance web reset page, which runs in any browser
/// - including this phone's - so the flow works for app and web
/// accounts alike. The response is uniform on purpose: it can never be
/// used to check whether an account exists.
class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({required this.isSchool});

  final bool isSchool;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final TextEditingController _identifier = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final String identifier = _identifier.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Enter your email (or username).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ApiClient api = context.read<ApiClient>();
    try {
      await api.forgotPassword(identifier);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
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

  @override
  Widget build(BuildContext context) {
    final String sentIdentifier = _identifier.text.trim().isEmpty
        ? 'that address'
        : _identifier.text.trim();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
                color: Color(0x1F111C2D), blurRadius: 24, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: context.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _sent ? 'Check your inbox' : 'Forgot password?',
                  style: RenanceText.displayMd,
                ),
                const SizedBox(height: 8),
                Text(
                  _sent
                      ? 'If $sentIdentifier belongs to a Renance account, a '
                          'reset link is on its way. It works once and expires '
                          'in 30 minutes - open it in any browser, set the new '
                          'password, then sign in here.'
                      : widget.isSchool
                          ? 'Enter the school email and we will send a reset '
                              'link. It opens in your browser.'
                          : 'Enter the email on your account and we will send '
                              'a reset link. Your username works too.',
                  style: RenanceText.bodySecondary.copyWith(
                      color: context.textSecondary, height: 1.45),
                ),
                if (_sent) ...<Widget>[
                  const SizedBox(height: 12),
                  // Spam-folder hint (founder directive 2026-10-02): the
                  // sending domain is new, providers may file Renance mail
                  // under spam at first.
                  Text(
                    "Nothing in your inbox? Check your spam folder - "
                    "open the mail and mark it 'Not spam' so Renance "
                    "lands in your main inbox next time.",
                    textAlign: TextAlign.center,
                    style: RenanceText.bodySecondary.copyWith(
                      fontSize: 12.5,
                      height: 1.45,
                      color: context.textSecondary,
                    ),
                  ),
                ],
                if (!_sent) ...<Widget>[
                  const SizedBox(height: 20),
                  TextField(
                    controller: _identifier,
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.alternate_email, size: 20),
                      hintText: 'you@example.com',
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: context.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Sending…' : 'Send reset link'),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
