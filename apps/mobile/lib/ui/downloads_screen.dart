/// The Downloads screen - the offline nerve centre.
///
/// Five download desks: JAMB offline, Post-UTME, WAEC, NECO and Schools
/// (with a school picker for staff). Any combination can be selected and
/// pulled in one go. The storage meter reads REAL bytes (UTF-8 pack
/// payloads + the sqlite file itself), refreshes live while downloads
/// run, and the permissions card surfaces every grant the app needs -
/// storage (only on the Android builds whose OS still shows that
/// dialog), notifications and the Wi-Fi/data connection state.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers.dart';
import '../models.dart';
import '../notifications.dart';
import '../storage.dart';
import 'university_screens.dart'
    show UniCourse, kUniversitySchools, universityCourses;
import 'msymbols.dart';
import 'tactile.dart';
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

  String _connectionIcon(ConnectivityResult c) {
    switch (c) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
      case ConnectivityResult.satellite:
        return 'signal_cellular_alt';
      default:
        return 'wifi_off';
    }
  }

  // ------------------------------------------------------------ actions

  /// Cached Android SDK int (null until probed, -1 = not Android).
  int? _androidSdk;

  Future<int> _androidSdkInt() async {
    if (_androidSdk != null) return _androidSdk!;
    try {
      if (kIsWeb) {
        _androidSdk = -1;
      } else {
        final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
        _androidSdk = info.version.sdkInt;
      }
    } catch (_) {
      _androidSdk = -1; // iOS/desktop: no legacy storage grants at all
    }
    return _androidSdk!;
  }

  /// Only Android 10 and below still ride the legacy storage grant for
  /// shared pack exports. Android 11+ (SDK 30+) scoped storage saves
  /// every pack inside the app's own directory and the OS retired the
  /// permission - requesting it pops NO dialog at all, which read as
  /// "the allow storage access permission is not popping up" (founder,
  /// 2026-10-02). On those builds the card says so instead of offering
  /// an Allow button that can never open anything.
  Future<bool> _needsLegacyStorage() async {
    final int sdk = await _androidSdkInt();
    return sdk > 0 && sdk <= 29;
  }

  Future<void> _ensurePermissions() async {
    // Notifications: every build (Android 13+ shows the real runtime
    // dialog). Storage: only where the OS can still show its dialog.
    final List<Permission> asks = <Permission>[Permission.notification];
    if (await _needsLegacyStorage()) {
      asks.add(Permission.storage);
    }
    await asks.request();
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
      final bool ok = sync.phase != SyncPhase.error;
      if (ok) {
        // Device notification (founder directive 2026-10-04): the
        // download result drops on the phone, not only in a snackbar.
        await RenanceNotifications.show(
          RenanceNotifications.downloadDoneId,
          'Renance · offline ready',
          'Every student question pack is downloaded and ready offline.',
        );
      }
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
        if (failed == 0) {
          await RenanceNotifications.show(
            RenanceNotifications.downloadDoneId,
            'Renance · school desk ready',
            '$ok packs downloaded - your school desk works offline now.',
          );
        }
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
    if (err == null && !syncFailed) {
      await RenanceNotifications.show(
        RenanceNotifications.downloadDoneId,
        'Renance · offline ready',
        'Everything you picked is downloaded and ready offline.',
      );
    }
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

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    // Watched for rebuilds: the desk tiles read the downloaded counts via
    // context.read inside their builders, but this screen must repaint the
    // moment a pack lands.
    context.watch<StudentController>();
    final SyncController sync = context.watch<SyncController>();
    final SchoolController school = context.watch<SchoolController>();

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
          _buildStorageCard(_bytesTotal, _dbBytes),
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
          TactileButton(
            // Never disabled for an empty selection: tapping with nothing
            // picked downloads EVERY student desk (the old disabled button
            // read as "the download is broken"). Marked School Desk
            // schools ride along first.
            onPressed: busy ? null : _downloadSelected,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const MsIcon('download', size: 20, fill: true),
                const SizedBox(width: 8),
                Text(
                  _selectedDesks.isEmpty &&
                          _selectedSchools.isEmpty &&
                          _selectedUniSchools.isEmpty
                      ? 'Download everything'
                      : 'Download ${_selectedDesks.length + _selectedSchools.length + _selectedUniSchools.length} selection(s)',
                ),
              ],
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

          // Founder directive (2026-10-02): the per-pack "Downloaded
          // exam packs" / "Downloaded school packs" shelves under the
          // Download everything button are GONE - they listed every
          // stored pack with "0 B" sizes (the mock question bank rows)
          // and duplicated what the storage meter already says honestly.
          // Pack management stays in Settings (clear offline data) and
          // the school workspace.
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

  String _deskIcon(String desk) {
    switch (desk) {
      case 'POST-UTME':
        return 'apartment';
      case 'WAEC':
        return 'school';
      case 'NECO':
        return 'history_edu';
      case 'GCSE':
        return 'public';
      case 'NEET':
        return 'medical_services';
      default:
        return 'verified';
    }
  }

  // ------------------------------------------------------------ widgets

  Widget _buildStorageCard(
    int bytes,
    int? dbBytes,
  ) {
    // The meter = how much of the device's Renance footprint is packs;
    // legend rows give the honest breakdown.
    final int packsBytes = bytes;
    final int db = dbBytes ?? 0;
    final int total = packsBytes + db;
    final double fraction = db == 0
        ? (packsBytes > 0 ? 1.0 : 0.0)
        : packsBytes / total;

    return TactileCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const MsIcon('storage', size: 20),
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
    return TactileCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const MsIcon('admin_panel_settings', size: 20),
                const SizedBox(width: 8),
                Text('Permissions', style: RenanceText.sectionTitle.copyWith(color: context.ink)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Storage is only needed on older Androids - modern builds save packs inside the app. Notifications show download progress, and the network state honours Wi-Fi only.',
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
                            // Green = usable right now (granted, or the
                            // OS version genuinely needs no grant). Amber
                            // = a dialog can still fix it. Red = the user
                            // blocked it, only Settings can undo that.
                            MsIcon(
                              p.blocked
                                  ? 'block'
                                  : p.ready
                                      ? 'check_circle'
                                      : 'error',
                              size: 18,
                              color: p.blocked
                                  ? context.error
                                  : p.ready
                                      ? const Color(0xFF00CD9C)
                                      : RenanceColors.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.ready
                                    ? (p.notNeeded
                                        ? '${p.label} - not needed; packs save inside the app'
                                        : p.label)
                                    : p.blocked
                                        ? '${p.label} - blocked. Allow it from Settings.'
                                        : '${p.label} - tap Allow to grant',
                                style: RenanceText.bodyBase.copyWith(
                                    color: context.ink, fontSize: 13),
                              ),
                            ),
                            if (p.canAsk)
                              TextButton(
                                onPressed: () async {
                                  // Only reached where the OS can really
                                  // show its dialog (Android 10- for
                                  // storage, every Android 13+ for
                                  // notifications).
                                  await p.permission.request();
                                  if (context.mounted) setState(() {});
                                },
                                child: const Text('Allow'),
                              )
                            else if (p.blocked)
                              TextButton(
                                onPressed: () async {
                                  await openAppSettings();
                                  if (context.mounted) setState(() {});
                                },
                                child: const Text('Settings'),
                              )
                            else if (p.ready)
                              const Text(
                                'Ready',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF00CD9C),
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
    // Storage: on Android 11+ the OS retired the legacy grant entirely -
    // packs live in app-private storage, nothing can be asked, and an
    // Allow button would be a dead tap (the founder's "permission is not
    // popping up" report, 2026-10-02). The row reports not-needed
    // instead, and the dialog only appears where it is real.
    final bool legacyStorage = await _needsLegacyStorage();
    final PermissionStatus storage = await Permission.storage.status;
    final PermissionStatus notifications =
        await Permission.notification.status;
    return <_PermState>[
      _PermState(
        label: 'Storage access (offline packs & sharing)',
        permission: Permission.storage,
        status: storage,
        notNeeded: !legacyStorage,
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
    return TactileCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
        secondary: MsIcon(
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
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TactileCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: Column(
          children: <Widget>[
          _DeskTile(
            title: 'School Desk (University)',
            subtitle:
                'Mark the school(s) you want, then download their packs',
            icon: 'account_balance',
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
      ),
      ),
    );
  }

  Widget _buildSchoolsTile(SchoolController school) {
    final bool expanded = _schoolsExpanded;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TactileCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: Column(
          children: <Widget>[
          _DeskTile(
            title: 'Schools',
            subtitle: 'Syllabus, scheme of work & notes for school staff',
            icon: 'school',
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
      ),
      ),
    );
  }
}

class _PermState {
  const _PermState({
    required this.label,
    required this.permission,
    required this.status,
    this.notNeeded = false,
  });

  final String label;
  final Permission permission;
  final PermissionStatus status;

  /// True when the OS build genuinely needs no grant for what the app
  /// does (Android 11+ scoped storage): the row reads Ready and no
  /// dialog is ever attempted - a request there pops nothing at all.
  final bool notNeeded;

  /// The app can actually use the capability right now: granted, the
  /// iOS-only limited slice, or not needed on this OS build at all.
  bool get ready =>
      notNeeded ||
      status == PermissionStatus.granted ||
      status == PermissionStatus.limited;

  /// The user permanently denied it (the OS stops showing the dialog):
  /// only the system Settings app can undo that now.
  bool get blocked => !notNeeded && status == PermissionStatus.permanentlyDenied;

  /// Only offer Allow while the OS can still show the dialog.
  bool get canAsk => !notNeeded && !blocked && status == PermissionStatus.denied;
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
  final String icon;
  final int packCount;
  final int downloadedCount;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool complete = packCount > 0 && downloadedCount >= packCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TactileCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: selected,
        onChanged: (bool? v) => onChanged(v ?? false),
        secondary: MsIcon(icon, size: 26, color: context.ink),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: RenanceText.bodyBase.copyWith(color: context.ink, fontWeight: FontWeight.w600),
              ),
            ),
            if (complete)
              const MsIcon('check_circle', size: 18, color: Color(0xFF00CD9C)),
          ],
        ),
        subtitle: Text(
          '$subtitle · $downloadedCount of ${packCount > 0 ? packCount : '?'} packs offline',
          style: RenanceText.caption.copyWith(color: context.textSecondary),
        ),
      ),
      ),
      ),
    );
  }
}
