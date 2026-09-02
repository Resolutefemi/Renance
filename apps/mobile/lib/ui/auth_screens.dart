/// Splash → route decision, plus the two credential screens.
/// The founder's mockups drive the visuals; the doctrine drives the fields:
/// registration captures STRICTLY username + password.
library;

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../config.dart';
import '../models.dart';
import '../controllers.dart';
import '../storage.dart';
import 'renance_logo.dart';
import 'theme.dart';

/// Shared scaffold for the credential screens (mockup layout: logo block,
/// white card form, footer link).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
  });

  final String title;
  final String subtitle;
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
                const RenanceMark(size: 72),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: RenanceColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: RenanceColors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: form,
                  ),
                ),
                const SizedBox(height: 24),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: RenanceColors.onSurfaceVariant,
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

/// Google sign-in button — rendered only when GOOGLE_WEB_CLIENT_ID was
/// baked at build time, mirroring the web app's graceful degradation.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.language, size: 18),
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
  final GoogleSignInAccount? account =
      await GoogleSignIn(serverClientId: googleWebClientId).signIn();
  if (account == null) return false;
  final GoogleSignInAuthentication auth = await account.authentication;
  final String? idToken = auth.idToken;
  if (idToken == null) {
    onError('Google did not return an ID token — try again');
    return false;
  }
  // Capture everything the continuation needs BEFORE the async gap, so no
  // BuildContext is used after await without a mounted check.
  final SessionStore session = context.read<SessionStore>();
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
      final AuthTokens res =
          await api.login(_username.text.trim(), _password.text);
      await session.save(res.token, res.user);
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
      if (mounted) setState(() => _error = 'Google sign-in failed — try again');
    }
    if (mounted) setState(() => _busy = false);
    sync.refreshPendingCount().ignore();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue your streak.',
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _FieldLabel('Username'),
          TextField(
            controller: _username,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline, size: 20),
              hintText: 'your username',
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Password'),
          _PasswordField(controller: _password, onSubmitted: _submit),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(color: RenanceColors.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: RenanceMark(size: 16, busy: true),
                  )
                : const Icon(Icons.arrow_forward, size: 18),
            label: Text(_busy ? 'Signing in…' : 'Sign In'),
          ),
          if (googleWebClientId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _GoogleButton(onPressed: _busy ? null : _signInWithGoogle),
          ],
        ],
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            "Don't have an account? ",
            style: TextStyle(color: RenanceColors.onSurfaceVariant, fontSize: 14),
          ),
          GestureDetector(
            onTap: () =>
                Navigator.of(context).pushReplacementNamed('/register'),
            child: const Text(
              'Sign up',
              style: TextStyle(
                color: RenanceColors.ink,
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
    try {
      final AuthTokens res =
          await api.register(_username.text.trim(), _password.text);
      await session.save(res.token, res.user);
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
      if (mounted) setState(() => _error = 'Google sign-in failed — try again');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: "Two fields. That's the whole form.",
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
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
          const SizedBox(height: 16),
          _FieldLabel('Password'),
          _PasswordField(controller: _password, onSubmitted: _submit),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(color: RenanceColors.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: RenanceMark(size: 16, busy: true),
                  )
                : const Icon(Icons.arrow_forward, size: 18),
            label: Text(_busy ? 'Creating…' : 'Start studying'),
          ),
          if (googleWebClientId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _GoogleButton(onPressed: _busy ? null : _signUpWithGoogle),
          ],
          const SizedBox(height: 10),
          const Text(
            "We'll ask about your school and exams right after — one quick modal.",
            textAlign: TextAlign.center,
            style: TextStyle(color: RenanceColors.outline, fontSize: 12),
          ),
        ],
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            'Already studying with us? ',
            style: TextStyle(color: RenanceColors.onSurfaceVariant, fontSize: 14),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
            child: const Text(
              'Sign in',
              style: TextStyle(
                color: RenanceColors.ink,
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
