/// The Downloads screen - the offline nerve centre.
///
/// Five download desks: JAMB offline, Post-UTME, WAEC, NECO and Schools
/// (with a school picker for staff). Any combination can be selected and
/// pulled in one go. The storage meter reads REAL bytes (UTF-8 pack
/// payloads + the sqlite file itself), refreshes live while downloads
/// run, and the permissions card surfaces every grant the app needs -
/// storage, notifications and the Wi-Fi/data connection state.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'school_screens.dart' show SchoolPackViewerScreen;
import 'university_screens.dart'
    show UniCourse, kUniversitySchools, universityCourses;
import 'theme.dart';

const String _wifiOnlyPref = 'renance.downloads.wifi_only';

/// The four core desks, in the order the screen has always shown them.
/// Extra bodies (GCSE, NEET, ...) join from the manifest at build time
/// of the widget - see the desk list in build().
const List<String> kCoreDesks = <String>['JAMB', 'POST-UTME', 'WAEC', 'NECO'];

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  Map<String, int> _sizes = <String, int>{};
  Map<String, int> _schoolSizes = <String, int>{};
  int? _dbBytes;
  List<ExamMeta> _exams = <ExamMeta>[];
  List<SchoolContextModel> _schools = <SchoolContextModel>[];
  final Set<String> _selectedDesks = <String>{};
  final Set<String> _selectedSchools = <String>{};
  /// School Desk (university) schools the student MARKED for download.
  /// Founder rule: university banks never ride "Download everything" -
  /// a student marks the particular school(s) they want first, then
  /// downloads exactly those packs.
  final Set<String> _selectedUniSchools = <String>{};
  bool _uniSchoolsExpanded = false;
  bool _schoolsExpanded = false;
  bool _wifiOnly = false;
  ConnectivityResult _connection = ConnectivityResult.none;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadSchools();
    });
    _listen();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  void _setConnection(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() {
      _connection =
          results.isEmpty ? ConnectivityResult.none : results.first;
    });
  }

  /// Live storage: recompute whenever any controller changes state, so
  /// the meter moves WHILE downloads run (the old screen loaded once and
  /// froze at zero).
  void _listen() {
    context.read<SyncController>().addListener(_load);
    context.read<StudentController>().addListener(_load);
    context.read<SchoolController>().addListener(_load);
    _connSub = Connectivity()
        .onConnectivityChanged
        .listen(
      (List<ConnectivityResult> results) => _setConnection(results),
      onError: (Object _) {},
    );
    Connectivity().checkConnectivity().then(_setConnection).catchError((Object _) {});
    SharedPreferences.getInstance().then((SharedPreferences p) {
      if (!mounted) return;
      setState(() => _wifiOnly = p.getBool(_wifiOnlyPref) ?? false);
    });
  }

  Future<void> _load() async {
    try {
      final PackStore store = context.read<PackStore>();
      final Map<String, int> sizes = await store.packSizes();
      final Map<String, int> schoolSizes = await store.schoolPackSizes();
      final int? dbBytes = await store.databaseSizeBytes();
      if (!mounted) return;
      setState(() {
        _sizes = sizes;
        _schoolSizes = schoolSizes;
        _dbBytes = dbBytes;
        _exams = context.read<SyncController>().exams;
      });
    } catch (_) {
      // Keep whatever we already had; a storage hiccup must not blank
      // the screen.
    }
  }

  Future<void> _loadSchools() async {
    final SchoolController school = context.read<SchoolController>();
    await school.loadContexts();
    if (!mounted) return;
    setState(() => _schools = school.contexts);
  }

  /// The manifest's School Desk (university) banks grouped by school.
  Map<String, List<UniCourse>> get _uniSchools =>
      universityCourses(_exams);

  int _uniSchoolDownloaded(String slug) {
    final Set<String> downloaded =
        context.read<StudentController>().downloaded;
    return (_uniSchools[slug] ?? const <UniCourse>[])
        .where((UniCourse c) => downloaded.contains(c.exam.code))
        .length;
  }

  /// Downloads every bank of the MARKED schools, one pipe at a time
  /// (downloadExam already retries its own network noise). Returns
  /// (downloaded, failed) counts for the honest summary snackbar.
  /// Controllers are captured up-front: no Provider lookup crosses an
  /// await inside the loop.
  Future<(int, int)> _downloadMarkedSchools() async {
    final SyncController sync = context.read<SyncController>();
    final StudentController student = context.read<StudentController>();
    final Map<String, List<UniCourse>> schools = _uniSchools;
    int ok = 0;
    int failed = 0;
    for (final String slug in _selectedUniSchools) {
      for (final UniCourse c in schools[slug] ?? const <UniCourse>[]) {
        if (student.downloaded.contains(c.exam.code)) continue;
        final bool success = await sync.downloadExam(c.exam);
        success ? ok++ : failed++;
      }
    }
    await student.refreshDownloaded();
    return (ok, failed);
  }

  // ------------------------------------------------------------- helpers

  String _titleFor(String code) {
    for (final ExamMeta e in _exams) {
      if (e.code == code) return e.title;
    }
    return code;
  }

  String _fmtBytes(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  int get _examBytesTotal =>
      _sizes.values.fold<int>(0, (int a, int b) => a + b);
  int get _schoolBytesTotal =>
      _schoolSizes.values.fold<int>(0, (int a, int b) => a + b);
  int get _bytesTotal => _examBytesTotal + _schoolBytesTotal;

  /// Per-desk pack inventory from the manifest.
  List<ExamMeta> _deskPacks(String body) => _exams
      .where((ExamMeta e) => e.body == body || e.category == body)
      .toList(growable: false);

  int _deskDownloaded(String body) {
    final Set<String> downloaded =
        context.read<StudentController>().downloaded;
    return _deskPacks(body).where((ExamMeta e) => downloaded.contains(e.code)).length;
  }

  String _connectionLabel(ConnectivityResult c) {
    switch (c) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Mobile data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.satellite:
        return 'Satellite';
      case ConnectivityResult.other:
        return 'Other network';
      case ConnectivityResult.none:
        return 'Offline';
    }
  }

  IconData _connectionIcon(ConnectivityResult c) {
    switch (c) {
      case ConnectivityResult.wifi:
        return Icons.wifi;
      case ConnectivityResult.mobile:
      case ConnectivityResult.satellite:
        return Icons.signal_cellular_alt;
      default:
        return Icons.wifi_off;
    }
  }

  // ------------------------------------------------------------ actions

  Future<void> _ensurePermissions() async {
    // Notification permission (Android 13+) and legacy storage. App-private
    // pack storage needs no grant on modern Android, but the user asked for
    // the app to ASK - so the permissions card drives it explicitly.
    await <Permission>[Permission.notification, Permission.storage].request();
    if (mounted) setState(() {});
  }

  Future<void> _downloadSelected() async {
    // Every Provider lookup happens BEFORE the first await: after an
    // async gap the lint (rightly) refuses `context.*`, and the late
    // lookups crashed silent paths during the founder's download bugs.
    final SyncController sync = context.read<SyncController>();
    final SchoolController school = context.read<SchoolController>();
    final StudentController student = context.read<StudentController>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (_wifiOnly && _connection != ConnectivityResult.wifi) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Wi-Fi only is on - connect to Wi-Fi or allow mobile data below.'),
        ),
      );
      return;
    }

    await _ensurePermissions();

    // Nothing picked means every STUDENT desk (founder: "I want the
    // download to download all student question pack", 2026-09-28) -
    // JAMB + WAEC + NECO + Post-UTME + GCSE + NEET (133 packs today).
    // School Desk banks stay OUT (founder, round 3: "the offline
    // download should not include school desks for students - student
    // have to mark the particular school they want to download");
    // marked schools, if any, download first.
    if (_selectedDesks.isEmpty &&
        _selectedSchools.isEmpty &&
        _selectedUniSchools.isEmpty) {
      await sync.bootstrap(profileExams: const <String>[]);
      await student.refreshDownloaded();
      await _load();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sync.phase == SyncPhase.error
                ? sync.message
                : 'Download complete - every student question pack is ready offline.',
          ),
        ),
      );
      return;
    }

    // Marked School Desk schools go first (founder rule: mark first,
    // then download).
    if (_selectedUniSchools.isNotEmpty) {
      final (int ok, int failed) = await _downloadMarkedSchools();
      if (!mounted) return;
      if (_selectedDesks.isEmpty && _selectedSchools.isEmpty) {
        await _load();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              failed == 0
                  ? 'School Desk ready offline - $ok packs downloaded.'
                  : 'School Desk: $ok downloaded, $failed failed - check your connection and retry.',
            ),
          ),
        );
        _selectedUniSchools.clear();
        setState(() {});
        return;
      }
    }

    final List<String> bodies = _selectedDesks.toList();
    bool syncFailed = false;
    String syncMessage = '';
    for (final String body in bodies) {
      // Always hand the desk to the sync controller: bootstrap fetches
      // the manifest itself, so this works even when the screen opened
      // before any manifest had loaded (the old code computed "missing"
      // from a possibly-empty manifest list and silently did NOTHING -
      // founder bug "download is not working at all", 2026-09-28).
      // bootstrap skips packs already on the device, so re-tapping the
      // desk is cheap.
      await sync.bootstrap(profileExams: <String>[body]);
      if (!mounted) return;
      if (sync.phase == SyncPhase.error) {
        syncFailed = true;
        syncMessage = '$body desk: ${sync.message}';
      }
      await student.refreshDownloaded();
    }

    for (final String schoolId in _selectedSchools) {
      await school.download(schoolId);
    }

    _selectedDesks.clear();
    _selectedSchools.clear();
    _selectedUniSchools.clear();
    await _load();
    if (!mounted) return;
    final String? err = school.lastError;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          err ??
              (syncFailed
                  ? syncMessage
                  : 'Downloads complete - everything is ready offline.'),
        ),
      ),
    );
  }

  Future<void> _removeSchool(String schoolId) async {
    await context.read<SchoolController>().remove(schoolId);
    await _load();
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final SyncController sync = context.watch<SyncController>();
    final SchoolController school = context.watch<SchoolController>();
    final Set<String> downloaded = student.downloaded;

    // Desks are MANIFEST-DRIVEN: the four core exam bodies first (stable
    // order), then every other secondary body the server ships (GCSE,
    // NEET, ...). The old hardcoded four hid the GCSE/NEET packs behind
    // an unreachable shelf - the founder's "download the WHOLE question
    // pack" report (2026-09-28).
    final List<String> desks = <String>[
      ...kCoreDesks,
      ..._exams
          .map((ExamMeta e) => e.body)
          .where((String b) =>
              b.isNotEmpty &&
              b != 'University Modules' &&
              !kCoreDesks.contains(b))
          .toSet(),
    ];
    final bool busy =
        sync.phase == SyncPhase.syncing || school.isDownloading;

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(title: const Text('Downloads')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          _buildStorageCard(_bytesTotal, _dbBytes, downloaded, school),
          const SizedBox(height: 14),
          _buildPermissionsCard(),
          const SizedBox(height: 14),
          _buildConnectionCard(),
          const SizedBox(height: 14),
          Text(
            'Choose what to download',
            style: RenanceText.sectionTitle.copyWith(color: context.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Select any combination - you can download more than one at a time.',
            style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 10),
          for (final String desk in desks)
            _DeskTile(
              title: _deskTitle(desk),
              subtitle: _deskSubtitle(desk),
              icon: _deskIcon(desk),
              packCount: _deskPacks(desk).length,
              downloadedCount: _deskDownloaded(desk),
              selected: _selectedDesks.contains(desk),
              onChanged: (bool v) => setState(() =>
                  v ? _selectedDesks.add(desk) : _selectedDesks.remove(desk)),
            ),
          _buildUniSchoolsSection(),
          // The staff Schools tile (syllabus/scheme/notes packs) only
          // exists for school accounts - students never see a staff
          // desk here (founder: school desks are not for students).
          if (_schools.isNotEmpty) _buildSchoolsTile(school),
          if (busy) ...<Widget>[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: sync.total > 0 ? sync.done / sync.total : null,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 6),
            Text(
              // The controller's own message carries the pack title
              // ("Downloading JAMB Chemistry… (3/46)") - show it so the
              // student SEES the download moving.
              sync.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RenanceText.caption.copyWith(color: context.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            // Never disabled for an empty selection: tapping with nothing
            // picked downloads EVERY student desk (the old disabled button
            // read as "the download is broken"). Marked School Desk
            // schools ride along first.
            onPressed: busy ? null : _downloadSelected,
            icon: const Icon(Icons.download_rounded, size: 20),
            label: Text(
              _selectedDesks.isEmpty &&
                      _selectedSchools.isEmpty &&
                      _selectedUniSchools.isEmpty
                  ? 'Download everything'
                  : 'Download ${_selectedDesks.length + _selectedSchools.length + _selectedUniSchools.length} selection(s)',
            ),
          ),
          if (_selectedUniSchools.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'School Desk marked - only the schools you ticked will download.',
              style: RenanceText.caption.copyWith(color: context.textSecondary),
            ),
          ],
          if (school.lastError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              school.lastError!,
              style: RenanceText.bodySecondary.copyWith(color: context.error),
            ),
          ],
          const SizedBox(height: 22),

          // Downloaded shelf ------------------------------------------------
          Text(
            'Downloaded exam packs',
            style: RenanceText.sectionTitle.copyWith(color: context.ink),
          ),
          const SizedBox(height: 8),
          if (downloaded.isEmpty)
            Text(
              'Nothing yet - pick desks above and tap Download.',
              style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
            )
          else
            ...downloaded.map((String code) {
              final int bytes = _sizes[code] ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.offline_pin, size: 24),
                  title: Text(
                    _titleFor(code),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.bodyBase.copyWith(color: context.ink),
                  ),
                  subtitle: Text(
                    '${_fmtBytes(bytes)} · ready offline',
                    style: RenanceText.caption.copyWith(color: context.textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      await context.read<PackStore>().removePack(code);
                      if (!context.mounted) return;
                      await context.read<StudentController>().refreshDownloaded();
                      await _load();
                    },
                  ),
                ),
              );
            }),

          Text(
            'Downloaded school packs',
            style: RenanceText.sectionTitle.copyWith(color: context.ink),
          ),
          const SizedBox(height: 8),
          if (school.packs.isEmpty)
            Text(
              'No school packs yet - staff can download their school\'s syllabus, scheme of work and notes above.',
              style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
            )
          else
            ...school.packs.values.map((SchoolPack pack) {
              final int bytes = _schoolSizes[pack.school.id] ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.school_outlined, size: 26),
                  title: Text(
                    pack.school.name,
                    style: RenanceText.bodyBase.copyWith(color: context.ink),
                  ),
                  subtitle: Text(
                    '${_fmtBytes(bytes)} · ${pack.topicCount} topics · v${pack.version}',
                    style: RenanceText.caption.copyWith(color: context.textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _removeSchool(pack.school.id),
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => SchoolPackViewerScreen(pack: pack),
                  )),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _deskTitle(String desk) {
    switch (desk) {
      case 'POST-UTME':
        return 'Post-UTME offline';
      case 'WAEC':
        return 'WAEC offline';
      case 'NECO':
        return 'NECO offline';
      case 'GCSE':
        return 'GCSE offline';
      case 'NEET':
        return 'NEET offline';
      default:
        return '$desk offline';
    }
  }

  String _deskSubtitle(String desk) {
    switch (desk) {
      case 'POST-UTME':
        return 'Past questions from Nigerian universities';
      case 'WAEC':
        return 'WASSCE past questions, all subjects';
      case 'NECO':
        return 'NECO past questions, all subjects';
      case 'GCSE':
        return 'GCSE exam-style banks, all subjects';
      case 'NEET':
        return 'NEET exam-style banks';
      default:
        return 'Past questions, all subjects';
    }
  }

  IconData _deskIcon(String desk) {
    switch (desk) {
      case 'POST-UTME':
        return Icons.apartment;
      case 'WAEC':
        return Icons.school;
      case 'NECO':
        return Icons.history_edu;
      case 'GCSE':
        return Icons.public;
      case 'NEET':
        return Icons.medical_services_outlined;
      default:
        return Icons.verified;
    }
  }

  // ------------------------------------------------------------ widgets

  Widget _buildStorageCard(
    int bytes,
    int? dbBytes,
    Set<String> downloaded,
    SchoolController school,
  ) {
    // The meter = how much of the device's Renance footprint is packs;
    // legend rows give the honest breakdown.
    final int packsBytes = bytes;
    final int db = dbBytes ?? 0;
    final int total = packsBytes + db;
    final double fraction = db == 0
        ? (packsBytes > 0 ? 1.0 : 0.0)
        : packsBytes / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.storage_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Storage', style: RenanceText.sectionTitle.copyWith(color: context.ink)),
                const Spacer(),
                Text(
                  _fmtBytes(total),
                  style: RenanceText.statNumber.copyWith(color: context.ink, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                backgroundColor: context.cardLow,
              ),
            ),
            const SizedBox(height: 10),
            _legendRow('Exam packs', _fmtBytes(_examBytesTotal)),
            _legendRow('School packs (syllabus + notes)', _fmtBytes(_schoolBytesTotal)),
            _legendRow('App database', dbBytes == null ? 'unavailable' : _fmtBytes(db)),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: RenanceText.caption.copyWith(color: context.textSecondary),
            ),
          ),
          Text(
            value,
            style: RenanceText.labelMono.copyWith(color: context.ink, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.admin_panel_settings_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Permissions', style: RenanceText.sectionTitle.copyWith(color: context.ink)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Downloads need storage (legacy devices), notifications for progress, and the network state to honour Wi-Fi only.',
              style: RenanceText.caption.copyWith(color: context.textSecondary),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<_PermState>>(
              future: _permStates(),
              builder: (BuildContext context,
                  AsyncSnapshot<List<_PermState>> snap) {
                final List<_PermState> perms = snap.data ?? const <_PermState>[];
                return Column(
                  children: <Widget>[
                    for (final _PermState p in perms)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: <Widget>[
                            // Green = the capability is usable right now.
                            // Amber = the OS still holds the grant behind a
                            // dialog. The old card showed an ERROR icon for
                            // "Android 13+ needs no legacy storage grant",
                            // which read as "allow access to storage is not
                            // working" (founder, 2026-09-28) - it is not an
                            // error, the packs just never needed it.
                            Icon(
                              p.ready
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              size: 18,
                              color: p.ready
                                  ? const Color(0xFF10B981)
                                  : RenanceColors.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.ready
                                    ? p.label
                                    // Android 13+ retires the legacy storage
                                    // grant: the OS reports permanently denied
                                    // even though app-private packs need
                                    // nothing. Say so plainly instead of an
                                    // Allow button that can never succeed.
                                    : p.retired
                                        ? '${p.label} - not needed on this Android version; packs save in the app\'s own storage'
                                        : '${p.label} - tap Allow to grant',
                                style: RenanceText.bodyBase.copyWith(
                                    color: context.ink, fontSize: 13),
                              ),
                            ),
                            if (!p.ready && p.canAsk)
                              TextButton(
                                onPressed: () async {
                                  await p.permission.request();
                                  if (context.mounted) setState(() {});
                                },
                                child: const Text('Allow'),
                              )
                            else if (p.retired)
                              const Text(
                                'Ready',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<_PermState>> _permStates() async {
    final PermissionStatus storage = await Permission.storage.status;
    final PermissionStatus notifications = await Permission.notification.status;
    return <_PermState>[
      _PermState(
        label: 'Storage access (offline packs & sharing)',
        permission: Permission.storage,
        status: storage,
      ),
      _PermState(
        label: 'Notifications (download progress)',
        permission: Permission.notification,
        status: notifications,
      ),
    ];
  }

  Widget _buildConnectionCard() {
    final bool isWifi = _connection == ConnectivityResult.wifi;
    return Card(
      child: SwitchListTile(
        secondary: Icon(
          _connectionIcon(_connection),
          color: _connection == ConnectivityResult.none
              ? context.error
              : context.ink,
        ),
        title: Text(
          'Download over Wi-Fi only',
          style: RenanceText.bodyBase.copyWith(color: context.ink, fontSize: 14),
        ),
        subtitle: Text(
          'Connection: ${_connectionLabel(_connection)}'
          '${isWifi ? ' - great for big packs' : ''}',
          style: RenanceText.caption.copyWith(color: context.textSecondary),
        ),
        value: _wifiOnly,
        onChanged: (bool v) {
          setState(() => _wifiOnly = v);
          SharedPreferences.getInstance().then((SharedPreferences p) {
            p.setBool(_wifiOnlyPref, v);
          });
        },
      ),
    );
  }

  /// The School Desk section: the manifest's university banks grouped
  /// by school. Students MARK the particular school(s) they want here;
  /// nothing downloads until they do (founder rule, round 3). The
  /// section stays collapsed until a manifest actually carries School
  /// Desk banks.
  Widget _buildUniSchoolsSection() {
    final Map<String, List<UniCourse>> schools = _uniSchools;
    if (schools.isEmpty) return const SizedBox.shrink();
    final int totalPacks =
        schools.values.fold<int>(0, (int a, List<UniCourse> l) => a + l.length);
    final int donePacks = schools.keys
        .fold<int>(0, (int a, String s) => a + _uniSchoolDownloaded(s));
    final List<String> slugs = schools.keys.toList()..sort();
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        children: <Widget>[
          _DeskTile(
            title: 'School Desk (University)',
            subtitle:
                'Mark the school(s) you want, then download their packs',
            icon: Icons.account_balance_outlined,
            packCount: totalPacks,
            downloadedCount: donePacks,
            selected: _selectedUniSchools.isNotEmpty,
            onChanged: (bool v) {
              setState(() {
                _uniSchoolsExpanded = v;
                _selectedUniSchools.clear();
              });
            },
          ),
          if (_uniSchoolsExpanded) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Tick only the particular school(s) you want to download.',
                      style: RenanceText.caption
                          .copyWith(color: context.textSecondary),
                    ),
                  ),
                  if (_selectedUniSchools.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          setState(() => _selectedUniSchools.clear()),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            for (final String slug in slugs)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  kUniversitySchools[slug]?.$1 ?? slug.toUpperCase(),
                  style: RenanceText.bodyBase
                      .copyWith(color: context.ink, fontSize: 14),
                ),
                subtitle: Text(
                  '${(schools[slug] ?? const <UniCourse>[]).length} packs · '
                  '${_uniSchoolDownloaded(slug)} on device'
                  '${kUniversitySchools.containsKey(slug) ? ' · ${kUniversitySchools[slug]!.$2}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RenanceText.caption
                      .copyWith(color: context.textSecondary),
                ),
                value: _selectedUniSchools.contains(slug),
                onChanged: (bool? v) => setState(() {
                  if (v ?? false) {
                    _selectedUniSchools.add(slug);
                  } else {
                    _selectedUniSchools.remove(slug);
                  }
                }),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSchoolsTile(SchoolController school) {
    final bool expanded = _schoolsExpanded;
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        children: <Widget>[
          _DeskTile(
            title: 'Schools',
            subtitle: 'Syllabus, scheme of work & notes for school staff',
            icon: Icons.school_outlined,
            packCount: _schools.length,
            downloadedCount: school.packs.length,
            selected: _selectedSchools.isNotEmpty,
            onChanged: (bool v) {
              setState(() {
                if (v) {
                  _schoolsExpanded = true;
                  for (final SchoolContextModel c in _schools) {
                    _selectedSchools.add(c.school.id);
                  }
                } else {
                  _selectedSchools.clear();
                }
              });
            },
          ),
          if (expanded) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _schools.isEmpty
                          ? 'Sign in as school management or a teacher to see your schools here.'
                          : 'Pick the schools to download:',
                      style: RenanceText.caption.copyWith(color: context.textSecondary),
                    ),
                  ),
                  if (_schools.isEmpty)
                    TextButton(
                      onPressed: _loadSchools,
                      child: const Text('Load my schools'),
                    ),
                ],
              ),
            ),
            for (final SchoolContextModel c in _schools)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  c.school.name,
                  style: RenanceText.bodyBase.copyWith(color: context.ink, fontSize: 14),
                ),
                subtitle: Text(
                  '${c.member.isManagement ? 'Management' : 'Teacher'}'
                  '${school.packs.containsKey(c.school.id) ? ' · downloaded' : ''}',
                  style: RenanceText.caption.copyWith(color: context.textSecondary),
                ),
                value: _selectedSchools.contains(c.school.id),
                onChanged: (bool? v) => setState(() {
                  if (v ?? false) {
                    _selectedSchools.add(c.school.id);
                  } else {
                    _selectedSchools.remove(c.school.id);
                  }
                }),
              ),
          ],
        ],
      ),
    );
  }
}

class _PermState {
  const _PermState({
    required this.label,
    required this.permission,
    required this.status,
  });

  final String label;
  final Permission permission;
  final PermissionStatus status;

  /// The app can actually use the capability right now: granted, or the
  /// iOS-only limited slice.
  bool get ready =>
      status == PermissionStatus.granted ||
      status == PermissionStatus.limited;

  /// The OS retired this grant (Android 13+ legacy storage): there is
  /// nothing to ask for and nothing is missing - the packs live in the
  /// app's private directory which needs no permission on those builds.
  bool get retired => status == PermissionStatus.permanentlyDenied;

  /// Only offer Allow while the OS can still show the dialog.
  bool get canAsk => status == PermissionStatus.denied;
}

/// One selectable download desk row.
class _DeskTile extends StatelessWidget {
  const _DeskTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.packCount,
    required this.downloadedCount,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int packCount;
  final int downloadedCount;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool complete = packCount > 0 && downloadedCount >= packCount;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: selected,
        onChanged: (bool? v) => onChanged(v ?? false),
        secondary: Icon(icon, size: 26, color: context.ink),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: RenanceText.bodyBase.copyWith(color: context.ink, fontWeight: FontWeight.w600),
              ),
            ),
            if (complete)
              const Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
          ],
        ),
        subtitle: Text(
          '$subtitle · $downloadedCount of ${packCount > 0 ? packCount : '?'} packs offline',
          style: RenanceText.caption.copyWith(color: context.textSecondary),
        ),
      ),
    );
  }
}
