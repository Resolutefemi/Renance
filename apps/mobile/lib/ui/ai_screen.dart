import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import 'theme.dart';

/// Renance AI: the study companion's own screen. A full chat grounded in
/// Renance's data (scheme of work, lesson notes, exam banks) through the
/// study API's /ai/chat. Strictly black and white: the student talks,
/// the AI answers in a paper-white card, and an honest mode chip shows
/// when the corpus-guide fallback is answering instead of full AI.
const List<String> _aiSuggestions = <String>[
  'Explain photosynthesis like I am in JSS 2, with a village example',
  'Quiz me: five JAMB Use of English questions, mark me after',
  'What topics come up in SSS 1 Physics first term?',
  'Teach me surds step by step with three worked examples',
];

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_AiTurn> _turns = <_AiTurn>[];
  bool _busy = false;



  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final String clean = text.trim();
    if (clean.isEmpty || _busy) return;
    setState(() {
      _turns.add(_AiTurn(role: 'user', content: clean));
      _busy = true;
    });
    _input.clear();
    _jumpToEnd();

    final ApiClient api = context.read<ApiClient>();
    final List<Map<String, String>> history = <Map<String, String>>[
      for (final _AiTurn t in _turns)
        <String, String>{'role': t.role, 'content': t.content},
    ];
    try {
      final AiChatReply reply = await api.aiChat(history);
      setState(() {
        _turns.add(_AiTurn(role: 'assistant', content: reply.text, mode: reply.mode));
        _busy = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _turns.add(_AiTurn(
          role: 'assistant',
          content: e.code == 'rate_limited'
              ? 'Renance AI is cooling down for a few seconds; try again shortly.'
              : 'Renance AI hit an error: ${e.message}',
        ));
        _busy = false;
      });
    } on NetworkException {
      setState(() {
        _turns.add(_AiTurn(
          role: 'assistant',
          content: 'No connection right now. Reconnect and continue the chat.',
        ));
        _busy = false;
      });
    }
    _jumpToEnd();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text('Renance AI', style: RenanceText.sectionTitle.copyWith(fontSize: 17)),
        actions: <Widget>[
          if (_turns.isNotEmpty)
            TextButton(
              onPressed: () => setState(_turns.clear),
              child: Text('Clear', style: RenanceText.bodySecondary.copyWith(fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _turns.isEmpty
                ? _Welcome(onSuggest: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    itemCount: _turns.length + (_busy ? 1 : 0),
                    itemBuilder: (BuildContext context, int i) {
                      if (i == _turns.length) return const _Typing();
                      return _Bubble(turn: _turns[i]);
                    },
                  ),
          ),
          // Composer -----------------------------------------------------
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              decoration: BoxDecoration(
                color: context.card,
                border: Border(top: BorderSide(color: context.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 1000,
                      enableInteractiveSelection: true,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      style: RenanceText.bodyBase.copyWith(fontSize: 14),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Ask Renance AI anything you are studying…',
                        hintStyle: RenanceText.bodySecondary.copyWith(
                          fontSize: 13.5, color: context.textSecondary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: context.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: context.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: context.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: context.ink),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _busy ? null : () => _send(_input.text),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.ink,
                      ),
                      child: Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: _busy ? context.textSecondary : context.pageBg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTurn {
  const _AiTurn({required this.role, required this.content, this.mode});
  final String role;
  final String content;
  final String? mode;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});
  final _AiTurn turn;

  @override
  Widget build(BuildContext context) {
    final bool user = turn.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (user) ...<Widget>[
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.ink,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  turn.content,
                  style: RenanceText.bodyBase.copyWith(fontSize: 13.5, color: context.pageBg),
                ),
              ),
            ),
          ] else ...<Widget>[
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: context.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SelectableText(
                      turn.content,
                      style: RenanceText.bodyBase.copyWith(fontSize: 13.5, height: 1.45),
                    ),
                    if (turn.mode == 'guide') ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'study-guide mode: the full AI brain is connecting',
                        style: RenanceText.caption.copyWith(
                          fontSize: 10.5,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: context.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < 3; i++) ...<Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.ink.withValues(alpha: 0.35),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSuggest});

  final ValueChanged<String> onSuggest;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Meet Renance AI',
                style: RenanceText.sectionTitle.copyWith(color: context.pageBg, fontSize: 19),
              ),
              const SizedBox(height: 8),
              Text(
                'Trained on Renance itself: the Nigerian scheme of work, '
                'lesson notes for every topic, and the exam banks. Ask it '
                'to teach, drill or mark you.',
                style: RenanceText.bodySecondary.copyWith(
                  fontSize: 13,
                  height: 1.5,
                  color: context.pageBg.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...List<Widget>.generate(_aiSuggestions.length, (int i) {
          final String s = _aiSuggestions[i];
          return Padding(
            padding: EdgeInsets.only(bottom: i == _aiSuggestions.length - 1 ? 0 : 8),
            child: InkWell(
              onTap: () => onSuggest(s),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Text(s, style: RenanceText.bodyBase.copyWith(fontSize: 13.5)),
              ),
            ),
          );
        }),
      ],
    );
  }
}
