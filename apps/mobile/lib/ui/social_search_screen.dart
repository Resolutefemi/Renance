/// Find friends - user search by username or name (founder directive
/// 2026-10-22: "add search for users features with username or name",
/// web parity with /profile/search). A debounced box over
/// GET /social/search; every row wears the RenanceFace identity and
/// opens the scholar's public profile, Duolingo-style.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../learn_models.dart' show SocialAuthor;
import 'face.dart';
import 'social_screens.dart' show PublicProfileScreen;
import 'theme.dart';

class SocialSearchScreen extends StatefulWidget {
  const SocialSearchScreen({super.key});

  @override
  State<SocialSearchScreen> createState() => _SocialSearchScreenState();
}

class _SocialSearchScreenState extends State<SocialSearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  bool _busy = false;
  String _error = '';
  List<SocialAuthor> _results = <SocialAuthor>[];
  // The follow edges the scholar flipped on THIS screen (username ->
  // following), so the chips flip instantly without a refetch.
  final Map<String, bool> _edges = <String, bool>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = <SocialAuthor>[];
        _busy = false;
        _error = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _run);
  }

  Future<void> _run() async {
    final String q = _ctrl.text.trim();
    if (q.length < 2) return;
    final ApiClient api = context.read<ApiClient>();
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final List<SocialAuthor> users = await api.socialSearch(q, limit: 25);
      if (!mounted) return;
      setState(() {
        _results = users;
        _busy = false;
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

  Future<void> _toggleFollow(SocialAuthor u) async {
    final ApiClient api = context.read<ApiClient>();
    final bool was = _edges[u.username] ?? false;
    setState(() => _edges[u.username] = !was);
    try {
      final bool following = await api.socialFollow(u.username);
      if (!mounted) return;
      setState(() => _edges[u.username] = following);
    } catch (_) {
      if (mounted) setState(() => _edges[u.username] = was);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(),
            decoration: InputDecoration(
              hintText: 'Search username or name',
              prefixIcon: const Icon(Icons.search, size: 22),
              isDense: true,
              filled: true,
              fillColor: context.surfaceContainer,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error,
                        textAlign: TextAlign.center,
                        style: RenanceText.bodySecondary
                            .copyWith(color: context.textSecondary)),
                  ),
                )
              : _results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _ctrl.text.trim().length < 2
                              ? 'Type at least two letters to find scholars '
                                  'by their username or name.'
                              : 'No scholar matches "${_ctrl.text.trim()}".',
                          textAlign: TextAlign.center,
                          style: RenanceText.bodySecondary
                              .copyWith(color: context.textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: _results.length,
                      itemBuilder: (BuildContext context, int i) {
                        final SocialAuthor u = _results[i];
                        final bool following = _edges[u.username] ?? false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                PublicProfileScreen.push(context, u.username),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                      color: Color(0x14141C2D),
                                      blurRadius: 3,
                                      offset: Offset(0, 1)),
                                ],
                              ),
                              child: Row(
                                children: <Widget>[
                                  RenanceFace(
                                    name: u.name,
                                    username: u.username,
                                    avatar: u.avatar,
                                    photoUrl: u.photo == null
                                        ? null
                                        : context.read<ApiClient>()
                                            .profilePhotoUrl(u.photo!),
                                    size: 44,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(u.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: RenanceText.bodyMedium
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text('@${u.username}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: RenanceText.bodySecondary
                                                .copyWith(
                                                    color: context
                                                        .textSecondary)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(behavior: HitTestBehavior.opaque,
                                    onTap: () => _toggleFollow(u),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: following
                                            ? context.surfaceContainer
                                            : context.primary,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        following ? 'FOLLOWING' : 'ADD',
                                        style: RenanceText.labelMono.copyWith(
                                          fontSize: 12,
                                          color: following
                                              ? context.textSecondary
                                              : context.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
