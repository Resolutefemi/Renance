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
import 'msymbols.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';

/// Shared scaffold for the credential screens - the web's auth shell:
/// a #f0f0f3 canvas, the keycap + heading block, the FOR STUDENTS / FOR
/// SCHOOLS pill toggle, then the white card form (logo INSIDE the card
/// on register/forgot, ABOVE it on login, the web's split).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.audience,
    required this.onAudienceChanged,
    required this.form,
    required this.footer,
    this.logoInCard = true,
    this.registerMode = false,
  });

  final String title;
  final String subtitle;
  final AuthAudience audience;
  final ValueChanged<AuthAudience> onAudienceChanged;
  final Widget form;
  final Widget footer;

  /// Login keeps the logo block above the white card; register wraps
  /// everything in one card (the web's two layouts).
  final bool logoInCard;

  /// The audience toggle's helper copy mode (login vs register).
  final bool registerMode;

  @override
  Widget build(BuildContext context) {
    final Widget logoBlock = Column(
      children: <Widget>[
        const RenanceMark(size: 64),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          // text-on-surface token - the dark tier lifts it to #F0F3F6.
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: context.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            color: context.textSecondary,
          ),
        ),
      ],
    );

    final Widget audienceBlock = Column(
      children: <Widget>[
        _AudienceToggle(
          value: audience,
          onChanged: onAudienceChanged,
        ),
        const SizedBox(height: 10),
        Text(
          registerMode
              ? (audience == AuthAudience.schools
                  ? 'Create your school workspace with management + teacher '
                      'accounts, syllabuses, notes and results.'
                  : '')
              : (audience == AuthAudience.schools
                  ? 'Management and teachers: sign in with your school email '
                      'to open the school workspace.'
                  : ''),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            color: Color(0xFF777777),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F3),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Column(
                children: <Widget>[
                  if (!logoInCard) ...<Widget>[
                    logoBlock,
                    const SizedBox(height: 20),
                    audienceBlock,
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: form,
                    ),
                  ] else ...<Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          logoBlock,
                          const SizedBox(height: 20),
                          audienceBlock,
                          const SizedBox(height: 20),
                          form,
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The FOR STUDENTS / FOR SCHOOLS segmented pill (audience-toggle.tsx):
/// a #f0f0f3 track, the active half filled primary with white ink.
class _AudienceToggle extends StatefulWidget {
  const _AudienceToggle({required this.value, required this.onChanged});

  final AuthAudience value;
  final ValueChanged<AuthAudience> onChanged;

  @override
  State<_AudienceToggle> createState() => _AudienceToggleState();
}

class _AudienceToggleState extends State<_AudienceToggle> {
  AuthAudience? _pressing;

  @override
  Widget build(BuildContext context) {
    final Color primary = context.primary;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          for (final AuthAudience a in AuthAudience.values)
            Expanded(
              child: GestureDetector(
                onTapDown: (_) => setState(() => _pressing = a),
                onTapCancel: () => setState(() => _pressing = null),
                onTapUp: (_) => setState(() => _pressing = null),
                onTap: () => widget.onChanged(a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  transform: Matrix4.translationValues(
                      0, _pressing == a ? 2 : 0, 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: a == widget.value ? primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: a == widget.value
                        ? <BoxShadow>[
                            // THE TACTILE KEY EDGE: the web's global
                            // `button.bg-primary` rule paints a hard 4px
                            // color-mix(primary 68%, #000) bottom edge on
                            // the active segment, collapsing to 2px (and
                            // sinking 2px) while pressed. Flat green pills
                            // here were the founder's #1 toggle complaint.
                            BoxShadow(
                              color: mixTowardBlack(primary, 0.68),
                              offset: const Offset(0, 4),
                              blurRadius: 0,
                            ),
                            // the web's Tailwind `shadow` ambient drop
                            const BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    a == AuthAudience.students
                        ? 'For Students'
                        : 'For Schools',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      // the tactile rule also stamps font-weight 800 on
                      // the active face
                      fontWeight: a == widget.value
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: a == widget.value
                          ? Colors.white
                          : const Color(0xFF777777),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
        // Founder 2026-10-21: the lock rode the well's top-left corner
        // at large font scales - the glyph now centres in a fixed 44px
        // hit area (MsFieldIcon), matching the web's muted field icons.
        prefixIcon: MsFieldIcon('lock',
            size: 20, color: context.textSecondary),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
        suffixIcon: IconButton(
          icon: MsIcon(
            _visible ? 'visibility' : 'visibility_off',
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
        icon: const MsIcon('devices_other', size: 32),
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
      icon: const MsIcon('phonelink_lock', size: 32),
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
          icon: const MsIcon('support_agent', size: 20),
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

/// The OR divider above the Google button (the web's google-signin.tsx):
/// hairline rules in outline-variant around a small uppercase 'or'.
class _GoogleDivider extends StatelessWidget {
  const _GoogleDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Divider(
            color: context.outlineVariant,
            thickness: 1,
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: context.outlineVariant,
            thickness: 1,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// Google sign-in button, rendered only when GOOGLE_WEB_CLIENT_ID was
/// baked at build time, mirroring the web app's graceful degradation.
/// (Students only - school staff sign in with their school email.)
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return TactileButton(
      onPressed: onPressed,
      outline: context.outlineVariant,
      edge: context.outlineVariant,
      edgeWidth: 3,
      height: 46,
      radius: BorderRadius.circular(12),
      fontSize: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          GoogleLogo(size: 18),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Continue with Google',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
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

  // The web's login card (app/login/page.tsx): email-first fields, the
  // error banner, the right-aligned forgot link, the h-12 rounded-lg
  // submit key, then the OR divider + Google key. Restored after the
  // parity pass accidentally dropped the build method.
  @override
  Widget build(BuildContext context) {
    final bool isSchool = _audience == AuthAudience.schools;
    return AuthScaffold(
      // The web's split: the logo block sits ABOVE the white card on
      // login (register wraps it inside).
      logoInCard: false,
      title: 'Welcome back',
      subtitle: isSchool
          ? 'Management and teachers sign in with the school email.'
          : 'Sign in to continue to Renance.',
      audience: _audience,
      onAudienceChanged: (AuthAudience a) => setState(() => _audience = a),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _FieldLabel(isSchool ? 'School email' : 'Email address'),
          TextField(
            controller: _username,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              prefixIcon: MsFieldIcon('mail',
                  size: 20, color: context.textSecondary),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 44, minHeight: 44),
              hintText: 'you@example.com',
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Password'),
          _PasswordField(controller: _password, onSubmitted: _submit),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: Color(0xFFB81F1F),
                ),
              ),
            ),
          ],
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
          const SizedBox(height: 20),
          TactileButton(
            onPressed: _busy ? null : _submit,
            height: 48,
            radius: BorderRadius.circular(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_busy) ...<Widget>[
                  const RenanceMark(size: 22, busy: true, onDark: true),
                  const SizedBox(width: 8),
                  const Text('Signing in…'),
                ] else ...<Widget>[
                  Text(isSchool ? 'Open school workspace' : 'Sign In'),
                  const SizedBox(width: 8),
                  const MsIcon('arrow_forward', size: 20),
                ],
              ],
            ),
          ),
          if (!isSchool && googleWebClientId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _GoogleDivider(),
            const SizedBox(height: 12),
            _GoogleButton(onPressed: _busy ? null : _signInWithGoogle),
          ],
        ],
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const Text(
            "Don't have an account? ",
            style: TextStyle(
              fontFamily: 'Nunito',
              color: Color(0xFF777777),
              fontSize: 14,
            ),
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
                fontFamily: 'Nunito',
                color: context.primary,
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
  // screen carries the FOR STUDENTS / FOR SCHOOLS tab across - "sign up
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
  final TextEditingController _password = TextEditingController();
  // Confirmation password (founder directive 2026-10-03): the password
  // is typed twice - a mismatch never leaves the phone.
  final TextEditingController _confirmPassword = TextEditingController();
  final FocusNode _confirmFocus = FocusNode();
  // School sign-up fields.
  final TextEditingController _schoolName = TextEditingController();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  // Referral code (optional): mints the referrer 100 diamonds.
  final TextEditingController _referral = TextEditingController();
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
    _password.dispose();
    _confirmPassword.dispose();
    _confirmFocus.dispose();
    _schoolName.dispose();
    _fullName.dispose();
    _email.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    // Consent gate (founder directive 2026-10-05): no tick, no account.
    if (!_acceptedTerms) {
      setState(() {
        _error =
            'Please accept the Terms of Service and Privacy Policy.';
      });
      return;
    }
    // The pair must match before anything is sent (students and school
    // sign-ups share the two fields).
    if (_password.text != _confirmPassword.text) {
      setState(() {
        _error = 'Passwords do not match.';
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
            _error = 'Enter the school name.';
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
      final String email = _email.text.trim().toLowerCase();
      if (email.isEmpty ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}\$').hasMatch(email)) {
        setState(() {
          _error =
              'Enter your email address - the confirmation code goes there.';
          _busy = false;
        });
        return;
      }
      if (_password.text.length < 8) {
        setState(() {
          _error = 'Passwords must be at least 8 characters.';
          _busy = false;
        });
        return;
      }
      // Email-first flow (web parity, the server's email branch): the
      // account is created from the address alone, the username seeds
      // from its local part, and the onboarding sheet asks for the
      // handle after the 6-digit code is verified.
      final AuthTokens res = await api.registerFull(
        email,
        password: _password.text,
        email: email,
        deviceId: await DeviceId.get(),
        referral: _referral.text.trim(),
      );
      await session.save(res.token, res.user);
      final SharedPreferences prefs = session.prefs;
      await SchoolController.forgetSchoolSession(prefs);
      if (!mounted) return;
      // Founder directive (2026-09-30): the signup does NOT enter the
      // desk until the emailed 6-digit code is consumed - the session
      // the API returned is restricted to the confirmation surface.
      await Navigator.of(context)
          .pushReplacementNamed('/verify', arguments: email);
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
            'Please accept the Terms of Service and Privacy Policy.';
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
    final bool mismatch = _confirmPassword.text.isNotEmpty &&
        _password.text != _confirmPassword.text;
    return AuthScaffold(
      logoInCard: true,
      registerMode: true,
      title: isSchool ? 'Register your school' : 'Create your account',
      subtitle: isSchool
          ? 'The educational app for your whole school: management, teachers '
              'and students.'
          : 'Join the global student educational app.',
      audience: _audience,
      onAudienceChanged: (AuthAudience a) => setState(() => _audience = a),
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
                hintText: 'e.g. Living Grace Academy',
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('School type'),
            DropdownButtonFormField<String>(
              initialValue: _schoolType,
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                    value: 'primary', child: Text('Primary school')),
                DropdownMenuItem<String>(
                    value: 'secondary', child: Text('Secondary school')),
                DropdownMenuItem<String>(
                    value: 'both',
                    child: Text('Both (primary + secondary)')),
              ],
              onChanged: (String? v) =>
                  setState(() => _schoolType = v ?? 'secondary'),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Your full name (management)'),
            TextField(
              controller: _fullName,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Mr Kelvin O.',
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('School email'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: MsFieldIcon('mail',
                    size: 20, color: context.textSecondary),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 44, minHeight: 44),
                hintText: 'you@example.com',
              ),
            ),
            const SizedBox(height: 16),
          ] else ...<Widget>[
            _FieldLabel('Email address'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const <String>[AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: MsFieldIcon('mail',
                    size: 20, color: context.textSecondary),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 44, minHeight: 44),
                hintText: 'you@example.com',
              ),
            ),
            const SizedBox(height: 16),
          ],
          _FieldLabel('Password'),
          _PasswordField(
            controller: _password,
            textInputAction: TextInputAction.next,
            onSubmitted: () => _confirmFocus.requestFocus(),
          ),
          const SizedBox(height: 6),
          Text(
            "At least 8 characters. We ask for the rest after you're in.",
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11.5,
              color: Color(0xFF777777),
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Confirm password'),
          _PasswordField(
            controller: _confirmPassword,
            hint: '••••••••',
            focusNode: _confirmFocus,
            onSubmitted: _submit,
          ),
          if (mismatch) ...<Widget>[
            const SizedBox(height: 6),
            const Text(
              'Passwords do not match.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11.5,
                color: Color(0xFFFF4B4B),
              ),
            ),
          ],
          if (!isSchool) ...<Widget>[
            const SizedBox(height: 16),
            _FieldLabel('Referral code (optional)'),
            TextField(
              controller: _referral,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'REN…',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your friend earns 100 diamonds when you join.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11.5,
                color: Color(0xFF777777),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Consent row (founder directive 2026-10-05): rides BOTH
          // signup forms, sits right above the submit.
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
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _acceptedTerms = !_acceptedTerms),
                  child: Text.rich(
                    TextSpan(
                      text: 'I accept the Terms of Service and ',
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
                                fontSize: 12.5,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      color: Color(0xFF777777),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: Color(0xFFB81F1F),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TactileButton(
            // Dead until the consent box is ticked (founder directive
            // 2026-10-05); _submit re-checks for belt and braces.
            onPressed: (_busy || !_acceptedTerms || mismatch)
                ? null
                : _submit,
            height: 48,
            radius: BorderRadius.circular(999),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_busy)
                  const RenanceMark(size: 22, busy: true, onDark: true)
                else
                  const MsIcon('arrow_forward', size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _busy
                      ? (isSchool ? 'Setting up school…' : 'Creating account…')
                      : isSchool
                          ? 'Create School Workspace'
                          : 'Create Account',
                ),
              ],
            ),
          ),
          if (!isSchool && googleWebClientId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _GoogleDivider(),
            const SizedBox(height: 12),
            _GoogleButton(onPressed: _busy ? null : _signUpWithGoogle),
          ],
        ],
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const Text(
            'Already have an account? ',
            style: TextStyle(
              fontFamily: 'Nunito',
              color: Color(0xFF777777),
              fontSize: 14,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pushReplacementNamed(
              '/login',
              arguments: _audience,
            ),
            child: Text(
              'Log In',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: context.primary,
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
                    decoration: InputDecoration(
                      prefixIcon: MsFieldIcon('alternate_email',
                          size: 20, color: context.textSecondary),
                      prefixIconConstraints: const BoxConstraints(
                          minWidth: 44, minHeight: 44),
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
                  TactileButton(
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
