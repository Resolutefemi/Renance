/// Renance AI Studio - the mobile companion rebuilt as a full studio
/// (founder directive, 2026-09-30): the grounded chat with visible
/// thinking phases, playable quiz generation, study notes, NotebookLM-
/// style notebooks and school lesson notes, all persisted server-side
/// with folders, history and memories. Generated documents open in the
/// canvas view with share-link and PDF export actions.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import 'ai_studio_widgets.dart';
import 'ai_sparkle.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

enum AiStudioTab { chat, quiz, note, notebook, lesson }

class AiScreen extends StatefulWidget {
  const AiScreen({super.key, this.initialTab});
  final AiStudioTab? initialTab;

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  late AiStudioTab _tab = widget.initialTab ?? AiStudioTab.chat;

  // The rail (end drawer) toggle. The AppBar hamburger must NOT use
  // Scaffold.of(context) with this State's context: that context sits
  // ABOVE the Scaffold, so the lookup throws and the tap does nothing
  // (founder bugfix 2026-10-02: the hamburger never opened). The key
  // reaches the ScaffoldState from anywhere, every tab.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // studio state
  AiBridgeStats? _stats;
  List<AiStudioChat> _chats = <AiStudioChat>[];
  List<AiStudioFolder> _folders = <AiStudioFolder>[];
  List<AiStudioMemory> _memories = <AiStudioMemory>[];
  List<AiStudioArtifact> _artifacts = <AiStudioArtifact>[];
  AiStudioChat? _activeChat;
  List<AiStudioMessage> _messages = <AiStudioMessage>[];
  bool _busy = false;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final List<AiStudioChat> chats = await api.aiChats();
      final List<AiStudioFolder> folders = await api.aiFolders();
      final List<AiStudioMemory> memories = await api.aiMemories();
      final List<AiStudioArtifact> artifacts = await api.aiArtifacts();
      final AiBridgeStats stats = await api.aiBridgeStats();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _folders = folders;
        _memories = memories;
        _artifacts = artifacts;
        _stats = stats;
      });
    } on Exception {
      // offline or signed out: the studio still renders, empty.
    }
  }

  // ------------------------------------------------------------- chat

  Future<void> _send(String text) async {
    final String clean = text.trim();
    if (clean.isEmpty || _busy) return;
    final ApiClient api = context.read<ApiClient>();
    setState(() {
      _busy = true;
      _messages = <AiStudioMessage>[
        ..._messages,
        AiStudioMessage(id: -1, role: 'user', content: clean),
      ];
    });
    _input.clear();
    _jumpToEnd();
    try {
      AiStudioChat chat = _activeChat ?? await api.aiCreateChat();
      final AiStudioChatTurn turn = await api.aiSendMessage(chat.id, clean);
      if (!mounted) return;
      setState(() {
        _activeChat = chat;
        _messages = <AiStudioMessage>[
          ..._messages.where((AiStudioMessage m) => m.id != -1),
          turn.userMessage,
          turn.assistantMessage,
        ];
        _busy = false;
      });
      if (turn.memorySaved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory saved')),
        );
      }
      _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      // Founder directive 2026-10-12 ("remove the fallback feature
      // completely - the AI answers directly"): the server no longer
      // saves a canned non-answer. A double provider failure surfaces
      // here as ai_unavailable; show a normal, retryable error bubble
      // the way every AI chat app does.
      setState(() {
        _messages = <AiStudioMessage>[
          ..._messages,
          AiStudioMessage(
            id: -2,
            role: 'assistant',
            content: e.code == 'rate_limited'
                ? 'Renance AI is cooling down for a few seconds; try again shortly.'
                : e.code == 'ai_unavailable'
                    ? 'Renance AI could not answer just now. Tap below and send the message again.'
                    : 'Renance AI hit an error: ${e.message}',
          ),
        ];
        _busy = false;
      });
    } on NetworkException {
      if (!mounted) return;
      setState(() {
        _messages = <AiStudioMessage>[
          ..._messages,
          const AiStudioMessage(
              id: -2, role: 'assistant', content: 'No connection right now. Reconnect and try again.'),
        ];
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

  void _openRail() => _scaffoldKey.currentState?.openEndDrawer();

  Future<void> _openChat(AiStudioChat c) async {
    final ApiClient api = context.read<ApiClient>();
    Navigator.of(context).pop(); // close the rail
    setState(() {
      _tab = AiStudioTab.chat;
      _activeChat = c;
      // Always start the thread empty: the old check compared the id
      // against the _activeChat we had JUST set, so it never cleared and
      // the previous chat's bubbles bled into the opened one.
      _messages = <AiStudioMessage>[];
    });
    try {
      final AiStudioChatThread t = await api.aiGetChat(c.id);
      if (!mounted) return;
      setState(() => _messages = t.messages);
    } on Exception {
      // keep the empty thread; sending will still work
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _newChat(String? folder) async {
    final ApiClient api = context.read<ApiClient>();
    if (mounted) Navigator.of(context).pop();
    try {
      final AiStudioChat c = await api.aiCreateChat(folder: folder);
      if (!mounted) return;
      setState(() {
        _tab = AiStudioTab.chat;
        _activeChat = c;
        _messages = <AiStudioMessage>[];
      });
      _refresh();
    } on Exception {
      _toast('Could not open a chat');
    }
  }

  Future<void> _saveMessageAsNote(AiStudioMessage m) async {
    final ApiClient api = context.read<ApiClient>();
    final TextEditingController c = TextEditingController(text: m.content.split('\n').first);
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Save as note'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Note title')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;
    try {
      await api.aiNoteFromText(title: title, content: m.content);
      _toast('Saved to your notes');
      _refresh();
    } on Exception {
      _toast('Could not save the note');
    }
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.pageBg,
      endDrawer: _StudioRail(
        stats: _stats,
        chats: _chats,
        folders: _folders,
        memories: _memories,
        artifacts: _artifacts,
        activeChatId: _activeChat?.id,
        onNewChat: _newChat,
        onOpenChat: _openChat,
        onOpenArtifact: (AiStudioArtifact a) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => AiArtifactScreen(artifact: a)),
          );
        },
        onAddMemory: (String content) async {
          final ApiClient api = context.read<ApiClient>();
          try {
            await api.aiAddMemory(content);
            _refresh();
          } on Exception {
            _toast('Could not save memory');
          }
        },
        onDeleteMemory: (int id) async {
          final ApiClient api = context.read<ApiClient>();
          try {
            await api.aiDeleteMemory(id);
            _refresh();
          } on Exception {
            // best effort
          }
        },
        onRenameChat: (AiStudioChat c) async {
          final ApiClient api = context.read<ApiClient>();
          final TextEditingController t = TextEditingController(text: c.title);
          final String? name = await showDialog<String>(
            context: context,
            builder: (BuildContext ctx) => AlertDialog(
              title: const Text('Rename chat'),
              content: TextField(controller: t, autofocus: true),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, t.text.trim()), child: const Text('Save')),
              ],
            ),
          );
          if (name == null || name.isEmpty) return;
          await api.aiUpdateChat(c.id, title: name);
          _refresh();
        },
        onDeleteChat: (AiStudioChat c) async {
          final ApiClient api = context.read<ApiClient>();
          await api.aiDeleteChat(c.id);
          if (!mounted) return;
          if (_activeChat?.id == c.id) {
            setState(() {
              _activeChat = null;
              _messages = <AiStudioMessage>[];
            });
          }
          _refresh();
        },
      ),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Dark-mode fix (founder directive 2026-10-11): the sparkle
            // used to sit in a primary-coloured box - white box + white
            // glyph in the stock dark tier, one blank chip. The box is
            // gone: the sparkle stands alone and follows the tier's ink
            // so it blends with the page colour in light AND dark.
            AiSparkleIcon(size: 21, color: context.ink),
            const SizedBox(width: 9),
            Text('Renance AI Studio',
                style: RenanceText.sectionTitle.copyWith(fontSize: 17)),
          ],
        ),
        actions: <Widget>[
          // New chat: the box-with-pencil affordance the flagship chat
          // products use (founder directive 2026-09-30).
          if (_tab == AiStudioTab.chat && _messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              onPressed: () {
                setState(() {
                  _activeChat = null;
                  _messages = <AiStudioMessage>[];
                });
              },
              icon: MsIcon('edit_square'),
            ),
          // The rail toggle: endDrawer does not auto-dock a button, so
          // the hamburger lives here - always reachable, every tab.
          IconButton(
            tooltip: 'Chats, folders and memories',
            onPressed: _openRail,
            icon: MsIcon('menu'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Tabs
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: <Widget>[
                for (final AiStudioTab t in AiStudioTab.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(switch (t) {
                        AiStudioTab.chat => 'Chat',
                        AiStudioTab.quiz => 'Quiz',
                        AiStudioTab.note => 'Note',
                        AiStudioTab.notebook => 'Notebook',
                        AiStudioTab.lesson => 'Lesson note',
                      }),
                      selected: _tab == t,
                      onSelected: (_) => setState(() => _tab = t),
                      labelStyle: RenanceText.bodyBase.copyWith(
                        fontSize: 13,
                        color: _tab == t ? context.onPrimary : context.ink,
                      ),
                      selectedColor: context.ink,
                      backgroundColor: context.card,
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: switch (_tab) {
              AiStudioTab.chat => _ChatTab(
                  stats: _stats,
                  messages: _messages,
                  busy: _busy,
                  controller: _input,
                  scroll: _scroll,
                  onSend: _send,
                  onSaveNote: _saveMessageAsNote,
                  onOpenRail: _openRail,
                ),
              AiStudioTab.quiz => _GenerateTab(
                  kind: 'quiz',
                  onArtifact: _openArtifact,
                  onOpenRail: _openRail,
                ),
              AiStudioTab.note => _GenerateTab(
                  kind: 'note',
                  onArtifact: _openArtifact,
                  onOpenRail: _openRail,
                ),
              AiStudioTab.notebook => _GenerateTab(
                  kind: 'notebook',
                  onArtifact: _openArtifact,
                  onOpenRail: _openRail,
                ),
              AiStudioTab.lesson => _GenerateTab(
                  kind: 'lesson_note',
                  onArtifact: _openArtifact,
                  onOpenRail: _openRail,
                ),
            },
          ),
        ],
      ),
    );
  }

  void _openArtifact(AiStudioArtifact a) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AiArtifactScreen(artifact: a)),
    );
    _refresh();
  }
}

// ---------------------------------------------------------------------------
// Chat tab
// ---------------------------------------------------------------------------

class _ChatTab extends StatelessWidget {
  const _ChatTab({
    required this.stats,
    required this.messages,
    required this.busy,
    required this.controller,
    required this.scroll,
    required this.onSend,
    required this.onSaveNote,
    required this.onOpenRail,
  });
  final AiBridgeStats? stats;
  final List<AiStudioMessage> messages;
  final bool busy;
  final TextEditingController controller;
  final ScrollController scroll;
  final ValueChanged<String> onSend;
  final ValueChanged<AiStudioMessage> onSaveNote;
  final VoidCallback onOpenRail;

  static const List<String> _suggestions = <String>[
    'Explain photosynthesis like I am in JSS 2, with a village example',
    'Show me real JAMB past questions on simple interest and solve them',
    'Teach me surds step by step with three worked examples',
    'Remember that I am in SSS 2 and my target is UNILAG for Medicine',
  ];

  static const List<String> _phases = <String>[
    'Thinking',
    'Analysing the topic',
    'Researching past questions',
    'Composing',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: messages.isEmpty && !busy
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: context.onPrimary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Center(
                                    child: AiSparkleIcon(size: 19)),
                              ),
                              const SizedBox(width: 8),
                              Text('Renance AI Studio',
                                  style: RenanceText.sectionTitle.copyWith(
                                      fontSize: 17, color: context.onPrimary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The study companion trained on Renance itself'
                            '${stats != null ? ' - ${stats!.questions} real past questions across ${stats!.exams} exam banks' : ' - 235,110+ real past questions'}'
                            ', the scheme of work and lesson notes. Ask it to teach, research past questions, drill or mark you.',
                            style: RenanceText.bodyBase.copyWith(
                                fontSize: 13, color: context.onPrimary.withValues(alpha: 0.75), height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final String s in _suggestions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: () => onSend(s),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.ink,
                            side: BorderSide(color: context.outlineVariant),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            alignment: Alignment.centerLeft,
                          ),
                          child: Text(s, style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: onOpenRail,
                        icon: MsIcon('menu', size: 16),
                        label: const Text('Folders, memories and documents'),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: messages.length + (busy ? 1 : 0),
                  itemBuilder: (BuildContext context, int i) {
                    if (i == messages.length) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: AiPhaseTicker(phases: _phases),
                        ),
                      );
                    }
                    return _StudioBubble(message: messages[i], onSaveNote: onSaveNote);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(alignment: Alignment.center,
            
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            decoration: BoxDecoration(
              color: context.card,
              border: Border(
                  top: BorderSide(color: context.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: 4000,
                    enableInteractiveSelection: true,
                    textInputAction: TextInputAction.send,
                    onSubmitted: onSend,
                    style: RenanceText.bodyBase.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Ask, teach me, or show me past questions on…',
                      hintStyle: RenanceText.bodySecondary.copyWith(
                          fontSize: 13.5, color: context.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                SizedBox(
                  width: 44,
                  child: TactileButton(
                    onPressed: busy ? null : () => onSend(controller.text),
                    height: 44,
                    radius: RenanceRadius.chip,
                    padding: EdgeInsets.zero,
                    face: context.primary,
                    onFace: context.onPrimary,
                    expand: false,
                    child: MsIcon('arrow_upward', size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Touch-safe question counter: a bordered box with fixed-width +/-
/// buttons and tabular digits. Replaces the raw IconButton row that
/// collided with the difficulty chips on narrow screens (founder
/// bugfix, 2026-09-30).
class _CountStepper extends StatelessWidget {
  const _CountStepper({
    required this.count,
    required this.min,
    required this.max,
    required this.onChange,
  });

  final int count;
  final int min;
  final int max;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _stepBtn(
            context,
            icon: 'remove',
            enabled: count > min,
            onTap: () => onChange(count - 1),
            left: true,
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: RenanceText.labelMono.copyWith(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          _stepBtn(
            context,
            icon: 'add',
            enabled: count < max,
            onTap: () => onChange(count + 1),
            left: false,
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(
    BuildContext context, {
    required String icon,
    required bool enabled,
    required VoidCallback onTap,
    required bool left,
  }) {
    return SizedBox(
      width: 38,
      height: 40,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(left ? 10 : 0),
          right: Radius.circular(left ? 0 : 10),
        ),
        child: MsIcon(
          icon,
          size: 18,
          color: enabled
              ? context.ink
              : context.textSecondary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _StudioBubble extends StatelessWidget {
  const _StudioBubble({required this.message, required this.onSaveNote});
  final AiStudioMessage message;
  final ValueChanged<AiStudioMessage> onSaveNote;

  @override
  Widget build(BuildContext context) {
    final bool mine = message.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.86),
        decoration: BoxDecoration(
          color: mine ? context.ink : context.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: context.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!mine && message.bridged > 0) ...<Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const MsIcon('travel_explore', size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'GROUNDED ON ${message.bridged} REAL PAST QUESTIONS',
                      style: RenanceText.labelMono.copyWith(fontSize: 8.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (!mine &&
                message.thinking != null &&
                message.thinking!.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  message.thinking!,
                  style: RenanceText.bodySecondary.copyWith(
                      fontSize: 11.5, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            Text(
              message.content,
              style: RenanceText.bodyBase.copyWith(
                fontSize: 13.5,
                color: mine ? context.onPrimary : context.ink,
                height: 1.45,
              ),
            ),
            if (!mine && message.id > 0) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  InkWell(
                    onTap: () => onSaveNote(message),
                    child: Row(
                      children: <Widget>[
                        const MsIcon('note_add', size: 13),
                        const SizedBox(width: 4),
                        Text('SAVE AS NOTE',
                            style: RenanceText.labelMono.copyWith(fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generator tab (quiz / note / notebook / lesson note)
// ---------------------------------------------------------------------------

class _GenerateTab extends StatefulWidget {
  const _GenerateTab({required this.kind, required this.onArtifact, required this.onOpenRail});
  final String kind; // quiz | note | notebook | lesson_note
  final ValueChanged<AiStudioArtifact> onArtifact;
  final VoidCallback onOpenRail;

  @override
  State<_GenerateTab> createState() => _GenerateTabState();
}

class _GenerateTabState extends State<_GenerateTab> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _topic = TextEditingController();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _classLevel = TextEditingController();
  final TextEditingController _topics = TextEditingController();
  String _difficulty = 'Medium';
  int _count = 5;
  String _template = 'detailed';
  String _term = 'First Term';
  final int _duration = 40;
  bool _busy = false;
  String? _error;

  static const List<String> _phases = <String>[
    'Thinking',
    'Analysing the topic',
    'Researching past questions',
    'Composing',
  ];

  @override
  void dispose() {
    _title.dispose();
    _topic.dispose();
    _subject.dispose();
    _classLevel.dispose();
    _topics.dispose();
    super.dispose();
  }

  List<String> _splitTopics(String s) => s
      .split(RegExp('[,;\n]'))
      .map((String t) => t.trim())
      .where((String t) => t.isNotEmpty)
      .toList();

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: RenanceText.bodySecondary
            .copyWith(fontSize: 13.5, color: context.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: context.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.ink)),
      );

  Future<void> _run() async {
    final ApiClient api = context.read<ApiClient>();
    setState(() => _error = null);
    try {
      AiStudioArtifact art;
      switch (widget.kind) {
        case 'quiz':
          final List<String> ts = _splitTopics(_topics.text);
          if (ts.isEmpty) {
            throw ApiException(400, 'invalid_topic', 'Add at least one topic.');
          }
          art = await api.aiGenerateQuiz(
            title: _title.text,
            topics: ts,
            difficulty: _difficulty,
            count: _count,
          );
        case 'note':
          if (_topic.text.trim().isEmpty) {
            throw ApiException(400, 'invalid_topic', 'Add a topic.');
          }
          art = await api.aiGenerateNote(
            topic: _topic.text.trim(),
            subject: _subject.text,
            classLevel: _classLevel.text,
            template: _template,
          );
        case 'notebook':
          final List<String> ts = _splitTopics(_topics.text);
          if (_subject.text.trim().isEmpty || ts.isEmpty) {
            throw ApiException(400, 'invalid_topics', 'Add the subject and topics.');
          }
          art = await api.aiGenerateNotebook(
            title: _title.text,
            subject: _subject.text.trim(),
            classLevel: _classLevel.text,
            topics: ts,
          );
        default: // lesson_note
          if (_subject.text.trim().isEmpty ||
              _classLevel.text.trim().isEmpty ||
              _topic.text.trim().isEmpty) {
            throw ApiException(
                400, 'invalid_request', 'Subject, class and topic are required.');
          }
          art = await api.aiGenerateLessonNote(
            subject: _subject.text.trim(),
            classLevel: _classLevel.text.trim(),
            topic: _topic.text.trim(),
            term: _term,
            duration: _duration,
          );
      }
      // The document generates in the background (Render's ~30s proxy
      // wall can cut a long provider call): the ticker keeps animating
      // while this loop watches the artifact row. Big quizzes generate
      // in server-side chunks, so the wait scales with the order.
      final AiStudioArtifact done = await api.aiWaitForArtifact(
        art,
        hintCount: widget.kind == 'quiz' ? _count : 0,
      );
      widget.onArtifact(done);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException {
      setState(() => _error = 'No connection right now. Try again when back online.');
    } on Exception {
      setState(() => _error = 'Generation failed, try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      // Founder directive (2026-10-02): say the wait out loud - students
      // tap Generate and expect instant output, but big quizzes generate
      // in server-side chunks and honestly take a while.
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AiPhaseTicker(phases: _phases),
              const SizedBox(height: 14),
              Text(
                'It may take some time - larger documents generate in chunks.',
                textAlign: TextAlign.center,
                style: RenanceText.bodySecondary
                    .copyWith(fontSize: 12.5, color: context.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AiSparkleIcon(size: 20, color: context.ink),
                    const SizedBox(width: 8),
                    Text(
                      switch (widget.kind) {
                        'quiz' => 'Quiz generator',
                        'note' => 'Study note generator',
                        'notebook' => 'Notebook generator',
                        _ => 'Lesson note generator',
                      },
                      style: RenanceText.sectionTitle.copyWith(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Grounded on the real past-question corpus.',
                  style: RenanceText.bodySecondary.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                if (widget.kind == 'quiz' || widget.kind == 'notebook') ...<Widget>[
                  TextField(
                    controller: _title,
                    decoration:
                        _deco(widget.kind == 'quiz' ? 'Quiz title (optional)' : 'Notebook title (optional)'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.kind == 'quiz' || widget.kind == 'notebook') ...<Widget>[
                  TextField(
                    controller: _topics,
                    maxLines: widget.kind == 'notebook' ? 3 : 1,
                    decoration: _deco('Topics, comma separated (e.g. photosynthesis, cell division)'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.kind == 'quiz') ...<Widget>[
                  TextField(
                    controller: _subject,
                    decoration: _deco('Subject (optional, e.g. Biology)'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.kind != 'quiz') ...<Widget>[
                  TextField(
                    controller: _subject,
                    decoration: _deco(widget.kind == 'lesson_note'
                        ? 'Subject (e.g. Biology)'
                        : 'Subject (e.g. Biology)'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.kind == 'note' || widget.kind == 'notebook' || widget.kind == 'lesson_note') ...<Widget>[
                  TextField(
                    controller: _topic,
                    decoration: _deco(widget.kind == 'lesson_note'
                        ? 'Topic (e.g. Cell division)'
                        : widget.kind == 'note'
                            ? 'Topic (e.g. Surds)'
                            : 'Focus topic (optional)'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.kind != 'quiz') ...<Widget>[
                  TextField(
                    controller: _classLevel,
                    decoration: _deco('Class (e.g. SSS 1)'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.kind == 'quiz') ...<Widget>[
                  // Founder bugfix (2026-09-30): difficulty chips and the
                  // question counter shared one Row, so on narrow screens
                  // the +/- steppers collided with the chip icons. They
                  // now stack, and the counter is its own touch-safe
                  // stepper with quick sizes up to 40.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        for (final String d in <String>['Easy', 'Medium', 'Hard'])
                          ChoiceChip(
                            label: Text(d),
                            selected: _difficulty == d,
                            onSelected: (_) => setState(() => _difficulty = d),
                            showCheckmark: false,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Text('Questions',
                          style: RenanceText.bodyBase.copyWith(fontSize: 13.5)),
                      const Spacer(),
                      _CountStepper(
                        count: _count,
                        min: 3,
                        max: 40,
                        onChange: (int v) => setState(() => _count = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      children: <Widget>[
                        for (final int n in <int>[5, 10, 20, 30, 40])
                          ChoiceChip(
                            label: Text('$n'),
                            labelStyle: RenanceText.labelMono.copyWith(
                                fontSize: 11.5,
                                color: _count == n
                                    ? context.onPrimary
                                    : context.textSecondary),
                            selected: _count == n,
                            onSelected: (_) => setState(() => _count = n),
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.kind == 'note') ...<Widget>[
                  Row(
                    children: <Widget>[
                      for (final String t in <String>['simple', 'detailed', 'revision'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t),
                            selected: _template == t,
                            onSelected: (_) => setState(() => _template = t),
                            showCheckmark: false,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.kind == 'lesson_note') ...<Widget>[
                  Row(
                    children: <Widget>[
                      for (final String t in <String>['First Term', 'Second Term', 'Third Term'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t.replaceFirst(' Term', '')),
                            selected: _term == t,
                            onSelected: (_) => setState(() => _term = t),
                            showCheckmark: false,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (_error != null) ...<Widget>[
                  Text(
                    _error!,
                    style: RenanceText.bodyBase
                        .copyWith(fontSize: 12.5, color: context.error),
                  ),
                  const SizedBox(height: 10),
                ],
                TactileButton(
                  onPressed: () {
                    setState(() => _busy = true);
                    _run();
                  },
                  height: 46,
                  radius: BorderRadius.circular(12),
                  face: context.inverseChip,
                  onFace: context.onInverseChip,
                  fontSize: 14,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const <Widget>[
                      MsIcon('auto_awesome', size: 18, fill: true),
                      SizedBox(width: 8),
                      Text('Generate with Renance AI'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onOpenRail,
            child: const Text('Your documents live in the rail - open it'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The rail (end drawer): folders, history, memories, documents
// ---------------------------------------------------------------------------

class _StudioRail extends StatelessWidget {
  const _StudioRail({
    required this.stats,
    required this.chats,
    required this.folders,
    required this.memories,
    required this.artifacts,
    required this.activeChatId,
    required this.onNewChat,
    required this.onOpenChat,
    required this.onOpenArtifact,
    required this.onAddMemory,
    required this.onDeleteMemory,
    required this.onRenameChat,
    required this.onDeleteChat,
  });
  final AiBridgeStats? stats;
  final List<AiStudioChat> chats;
  final List<AiStudioFolder> folders;
  final List<AiStudioMemory> memories;
  final List<AiStudioArtifact> artifacts;
  final String? activeChatId;
  final void Function(String? folder) onNewChat;
  final ValueChanged<AiStudioChat> onOpenChat;
  final ValueChanged<AiStudioArtifact> onOpenArtifact;
  final ValueChanged<String> onAddMemory;
  final ValueChanged<int> onDeleteMemory;
  final ValueChanged<AiStudioChat> onRenameChat;
  final ValueChanged<AiStudioChat> onDeleteChat;

  @override
  Widget build(BuildContext context) {
    final TextEditingController mem = TextEditingController();
    return Drawer(
      backgroundColor: context.pageBg,
      width: MediaQuery.of(context).size.width * 0.9,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Renance AI',
                      style: RenanceText.sectionTitle.copyWith(fontSize: 17)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: MsIcon('close'),
                ),
              ],
            ),
            if (stats != null)
              Text(
                'Bridged into ${stats!.questions} real past questions across ${stats!.exams} banks.',
                style: RenanceText.bodySecondary.copyWith(fontSize: 12),
              ),
            const SizedBox(height: 12),
            TactileButton(
              onPressed: () => onNewChat(null),
              height: 46,
              radius: BorderRadius.circular(12),
              fontSize: 14,
              face: context.inverseChip,
              onFace: context.onInverseChip,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  MsIcon('edit_square', size: 17),
                  SizedBox(width: 8),
                  Text('New chat'),
                ],
              ),
            ),
            const SizedBox(height: 6),
            TactileButton(
              onPressed: () {
                final TextEditingController f = TextEditingController();
                showDialog<String>(
                  context: context,
                  builder: (BuildContext ctx) => AlertDialog(
                    title: const Text('New folder'),
                    content: TextField(controller: f, autofocus: true),
                    actions: <Widget>[
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, f.text.trim()),
                          child: const Text('Create')),
                    ],
                  ),
                ).then((String? name) {
                  if (name != null && name.isNotEmpty) onNewChat(name);
                });
              },
              height: 46,
              radius: BorderRadius.circular(12),
              fontSize: 14,
              outline: context.outlineVariant,
              edge: context.outlineVariant,
              edgeWidth: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  MsIcon('create_new_folder', size: 18),
                  SizedBox(width: 8),
                  Text('New folder'),
                ],
              ),
            ),
            if (folders.isNotEmpty) ...<Widget>[
              const _RailHeading('Folders'),
              for (final AiStudioFolder f in folders)
                ListTile(
                  dense: true,
                  leading: MsIcon('folder', size: 20),
                  title: Text(f.name,
                      style: RenanceText.bodyBase.copyWith(fontSize: 13.5)),
                  trailing: Text('${f.count}',
                      style: RenanceText.labelMono.copyWith(fontSize: 11)),
                ),
            ],
            const _RailHeading('History'),
            if (chats.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('No chats yet.',
                    style: RenanceText.bodySecondary.copyWith(fontSize: 12.5)),
              ),
            for (final AiStudioChat c in chats)
              ListTile(
                dense: true,
                selected: c.id == activeChatId,
                leading: MsIcon('chat_bubble', size: 20),
                title: Text(c.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: RenanceText.bodyBase.copyWith(fontSize: 13.5)),
                subtitle: Text(c.folder,
                    style: RenanceText.labelMono.copyWith(fontSize: 9)),
                onTap: () => onOpenChat(c),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    InkWell(
                        onTap: () => onRenameChat(c),
                        child: MsIcon('edit', size: 16)),
                    const SizedBox(width: 10),
                    InkWell(
                        onTap: () => onDeleteChat(c),
                        child: MsIcon('delete', size: 16)),
                  ],
                ),
              ),
            const _RailHeading('Documents'),
            if (artifacts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Quizzes, notes, notebooks and lesson notes you generate land here.',
                  style: RenanceText.bodySecondary.copyWith(fontSize: 12.5),
                ),
              ),
            for (final AiStudioArtifact a in artifacts)
              ListTile(
                dense: true,
                leading: MsIcon(
                  a.kind == 'quiz'
                      ? 'quiz'
                      : a.kind == 'notebook'
                          ? 'menu_book'
                          : a.kind == 'lesson_note'
                              ? 'co_present'
                              : 'description',
                  size: 20,
                ),
                title: Text(a.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: RenanceText.bodyBase.copyWith(fontSize: 13.5)),
                onTap: () => onOpenArtifact(a),
              ),
            const _RailHeading('Memories'),
            if (memories.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Tell it "remember that..." and the fact follows you into every chat.',
                  style: RenanceText.bodySecondary.copyWith(fontSize: 12.5),
                ),
              ),
            for (final AiStudioMemory m in memories)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(m.content,
                            style:
                                RenanceText.bodyBase.copyWith(fontSize: 12.5)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onDeleteMemory(m.id),
                      icon: MsIcon('close', size: 16),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: mem,
                    maxLength: 400,
                    decoration: _railDeco(context, 'e.g. I write JAMB next April'),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    if (mem.text.trim().isNotEmpty) {
                      onAddMemory(mem.text.trim());
                      mem.clear();
                    }
                  },
                  customBorder: const CircleBorder(),
                  child: Container(alignment: Alignment.center,
                    
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: context.ink),
                    child: MsIcon('add', color: context.onPrimary, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _railDeco(BuildContext context, String hint) => InputDecoration(
        counterText: '',
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: context.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.outlineVariant)),
      );
}

class _RailHeading extends StatelessWidget {
  const _RailHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 4),
        child: Text(
          text.toUpperCase(),
          style: RenanceText.labelMono.copyWith(
              fontSize: 10, color: context.textSecondary),
        ),
      );
}

// ---------------------------------------------------------------------------
// The artifact canvas screen
// ---------------------------------------------------------------------------

/// Opens one generated document: quiz playable inline, notes rendered
/// with the house template, share-link (quizzes) and PDF export.
class AiArtifactScreen extends StatelessWidget {
  const AiArtifactScreen({super.key, required this.artifact});
  final AiStudioArtifact artifact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text(
          artifact.title.isEmpty ? 'Renance AI' : artifact.title,
          style: RenanceText.sectionTitle.copyWith(fontSize: 16),
        ),
        actions: <Widget>[
          if (artifact.kind == 'quiz')
            IconButton(
              tooltip: 'Share link',
              onPressed: () async {
                try {
                  await shareQuizLink(artifact, context.read<ApiClient>());
                } on Exception {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not create the link')));
                  }
                }
              },
              icon: MsIcon('share'),
            ),
          IconButton(
            tooltip: 'Export PDF',
            onPressed: () => shareArtifactPdf(artifact),
            icon: MsIcon('picture_as_pdf'),
          ),
        ],
      ),
      body: Builder(
        builder: (BuildContext ctx) {
          final bool pending = artifact.data['pending'] == true;
          final String? genError = artifact.data['error']?.toString();
          if (pending || (genError != null && genError.isNotEmpty)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    MsIcon(
                      pending ? 'hourglass_top' : 'error',
                      size: 40,
                      color: context.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pending ? 'Still writing this document…' : 'The document did not finish',
                      style: RenanceText.sectionTitle.copyWith(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pending
                          ? 'It may take some time. Renance AI is grounding it on real past questions - it lands here automatically.'
                          : genError ?? 'Try regenerating from the studio.',
                      style: RenanceText.bodySecondary.copyWith(
                          fontSize: 12.5, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        switch (artifact.kind) {
                          'quiz' => 'QUIZ',
                          'notebook' => 'NOTEBOOK',
                          'lesson_note' => 'LESSON NOTE',
                          _ => 'STUDY NOTE',
                        },
                        style: RenanceText.labelMono.copyWith(
                            fontSize: 9.5, color: context.onPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        <String>[
                          if (artifact.subject.isNotEmpty) artifact.subject,
                          if (artifact.classLevel.isNotEmpty) artifact.classLevel,
                        ].join(' - '),
                        style: RenanceText.bodySecondary.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (artifact.kind == 'quiz') AiQuizPlayer(artifact: artifact),
                if (artifact.kind == 'note') AiNoteView(data: artifact.data),
                if (artifact.kind == 'notebook')
                  AiNotebookView(data: artifact.data),
                if (artifact.kind == 'lesson_note')
                  AiLessonNoteView(data: artifact.data),
              ],
            ),
          );
        },
      ),
    );
  }
}
