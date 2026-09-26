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

import '../api_client.dart';
import '../config.dart';
import '../device_id.dart';
import '../models.dart';
import '../controllers.dart';
import '../storage.dart';
import 'google_logo.dart';
import 'renance_logo.dart';
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

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      textInputAction: TextInputAction.done,
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
        hintText: 'at least 8 characters',
      ),
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
  final AuthTokens res = await api.authWithGoogle(idToken);
  await session.save(res.token, res.user);
  if (!context.mounted) return true;
  await Navigator.of(context).pushReplacementNamed('/home');
  return true;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthAudience _audience = AuthAudience.students;
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
      final AuthTokens res = await api.loginFull(
        _username.text.trim(),
        password: _password.text,
        deviceId: await DeviceId.get(),
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
      // Strict email check: a manual signup confirms the inbox before
      // the desk opens. Google accounts arrive pre-verified.
      try {
        final MeResult me = await api.me();
        if (me.entitlement != null && !me.entitlement!.emailVerified) {
          if (!mounted) return;
          await Navigator.of(context).pushReplacementNamed('/verify');
          return;
        }
      } on NetworkException catch (_) {
        // offline: let the desk open, the next sync re-checks.
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
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
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Google sign-in failed, try again');
    }
    if (mounted) setState(() => _busy = false);
    sync.refreshPendingCount().ignore();
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
          if (_error != null) ...<Widget>[
            SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(color: context.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? RenanceMark(
                    size: 16,
                    busy: true,
                    // The CTA ground is black in light and white in dark,
                    // so the mark cut inverts with the tier.
                    onDark: Theme.of(context).brightness == Brightness.light,
                  )
                : const Icon(Icons.arrow_forward, size: 18),
            label: Text(
              _busy
                  ? 'Signing in…'
                  : isSchool
                      ? 'Open school workspace'
                      : 'Sign In',
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
            onTap: () =>
                Navigator.of(context).pushReplacementNamed('/register'),
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
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  AuthAudience _audience = AuthAudience.students;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  // School sign-up fields.
  final TextEditingController _schoolName = TextEditingController();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  String _schoolType = 'secondary';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _schoolName.dispose();
    _fullName.dispose();
    _email.dispose();
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
      final AuthTokens res = await api.registerFull(
        _username.text.trim(),
        password: _password.text,
        deviceId: await DeviceId.get(),
      );
      await session.save(res.token, res.user);
      final SharedPreferences prefs = session.prefs;
      await SchoolController.forgetSchoolSession(prefs);
      if (!mounted) return;
      // Manual signups confirm their email: the mailed link returns to
      // the app (verifyReturn: app). The notice shows before the home
      // shell; the student can keep exploring in the meantime.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created. Check your inbox for the confirmation link to fully unlock your account.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
      await Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
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

  Future<void> _signUpWithGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _runGoogleSignIn(context, onError: (message) {
        if (mounted) setState(() => _error = message);
      });
    } on ApiException catch (e) {
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
          : "Two fields. That's the whole form.",
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
                hintText: 'e.g. God Generals Standard Academy',
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
                hintText: 'e.g. Mrs. Ariyo O.',
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
          ],
          _FieldLabel('Password'),
          _PasswordField(controller: _password, onSubmitted: _submit),
          if (_error != null) ...<Widget>[
            SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(color: context.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? RenanceMark(
                    size: 16,
                    busy: true,
                    onDark: Theme.of(context).brightness == Brightness.light,
                  )
                : const Icon(Icons.arrow_forward, size: 18),
            label: Text(
              _busy
                  ? 'Setting up…'
                  : isSchool
                      ? 'Create school workspace'
                      : 'Start studying',
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
                : "We'll ask about your school and exams right after, in one quick modal.",
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
            onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
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
