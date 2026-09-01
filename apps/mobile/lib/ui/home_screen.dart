/// Home: the silent asset-sync strip, the offline pack library, the
/// pending-submission banner, and the contextual profile modal that must
/// complete before anything else happens.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'onboarding_sheet.dart';
import 'exam_screen.dart';
import 'renance_logo.dart';
import 'theme.dart';

const List<String> kExamOptions = <String>[
  'JAMB',
  'WAEC',
  'NECO',
  'University Modules',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  MeResult? _me;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_bootstrap);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<SyncController>().retryPending();
    }
  }

  Future<void> _bootstrap({bool force = false}) async {
    final ApiClient api = context.read<ApiClient>();
    final SessionStore session = context.read<SessionStore>();
    final SyncController sync = context.read<SyncController>();
    try {
      final MeResult me = await api.me();
      if (!mounted) return;
      setState(() => _me = me);
      if (me.profile == null || !me.profile!.completed) {
        _showOnboarding();
        return;
      }
      await sync.bootstrap(profileExams: me.profile!.exams);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await session.clear();
        if (!mounted) return;
        await Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      sync.surfaceFailure(e.message);
    } on NetworkException catch (e) {
      sync.surfaceFailure(e.message);
    }
    if (mounted) {
      setState(() {}); // rebuild after first sync cycle
    }
  }

  void _showOnboarding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const OnboardingSheet(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final SyncController sync = context.watch<SyncController>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const RenanceMark(size: 34),
            const SizedBox(width: 10),
            Text(
              _me?.profile?.fullName.isNotEmpty == true
                  ? 'Hi, ${_me!.profile!.fullName.split(' ').first}'
                  : 'Renance',
              style: const TextStyle(
                color: RenanceColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () async {
              await context.read<SessionStore>().clear();
              if (!context.mounted) return;
              await Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _bootstrap(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: <Widget>[
            _SyncStrip(sync: sync),
            if (sync.pendingCount > 0) ...<Widget>[
              const SizedBox(height: 12),
              _PendingBanner(),
            ],
            const SizedBox(height: 20),
            const Text(
              'YOUR STUDY PACKS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: RenanceColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...sync.exams.map((ExamMeta e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PackCard(exam: e),
                )),
            if (sync.exams.isEmpty && !sync.isSyncing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: LogoActivityIndicator(
                    label: 'Loading your library…',
                    size: 34,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncStrip extends StatelessWidget {
  const _SyncStrip({required this.sync});
  final SyncController sync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (sync.phase) {
            SyncPhase.syncing => LogoActivityIndicator(
                key: ValueKey<String>('sync-${sync.done}-${sync.message}'),
                label: sync.message,
              ),
            SyncPhase.ready => Row(
                key: const ValueKey<String>('ready'),
                children: <Widget>[
                  const RenanceMark(size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sync.message,
                      style: const TextStyle(
                        color: RenanceColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.offline_pin_outlined,
                      size: 18, color: RenanceColors.emerald),
                ],
              ),
            SyncPhase.error => Row(
                key: const ValueKey<String>('error'),
                children: <Widget>[
                  const Icon(Icons.cloud_off_outlined,
                      size: 20, color: RenanceColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sync.message,
                      style: const TextStyle(
                        color: RenanceColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            SyncPhase.idle => const LogoActivityIndicator(
                key: ValueKey<String>('idle'),
                label: 'Preparing your study pack…',
              ),
          },
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final SyncController sync = context.watch<SyncController>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RenanceColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.schedule, size: 18, color: RenanceColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${sync.pendingCount} finished paper(s) waiting to sync',
              style: const TextStyle(fontSize: 13, color: RenanceColors.ink),
            ),
          ),
          TextButton(
            onPressed: () => sync.retryPending(),
            child: const Text('Retry now'),
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.exam});
  final ExamMeta exam;

  @override
  Widget build(BuildContext context) {
    final SyncController sync = context.watch<SyncController>();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ExamScreen(exam: exam),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: RenanceColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exam.questionCount} questions'
                      '${exam.durationMinutes != null ? ' · ${exam.durationMinutes} min' : ''}'
                      ' · ${exam.totalMarks} marks',
                      style: const TextStyle(
                        fontSize: 12,
                        color: RenanceColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _PackCardTrailing(sync: sync),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackCardTrailing extends StatelessWidget {
  const _PackCardTrailing({required this.sync});

  final SyncController sync;

  @override
  Widget build(BuildContext context) {
    final bool ready = sync.phase == SyncPhase.ready;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (ready) ...<Widget>[
          const Icon(Icons.offline_pin, size: 16, color: RenanceColors.emerald),
          const SizedBox(width: 6),
          const Text(
            'Ready offline',
            style: TextStyle(fontSize: 12, color: RenanceColors.emerald),
          ),
        ] else
          const RenanceMark(size: 22, busy: true),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, size: 20, color: RenanceColors.outline),
      ],
    );
  }
}
