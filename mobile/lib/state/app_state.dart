import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../util/time_format.dart';

/// Result of signing in or signing up.
class AuthResult {
  const AuthResult._(this.ok, this.offline, this.error);
  const AuthResult.ok() : this._(true, false, null);
  const AuthResult.offline() : this._(true, true, null);
  const AuthResult.error(String message) : this._(false, false, message);

  final bool ok;
  final bool offline;
  final String? error;
}

/// All app data lives here.
///
/// Signed in to the server: every change is sent to the FastAPI backend and
/// the app refreshes from it every few seconds, so Rosa's and David's phones
/// stay in sync. Server not reachable: the app keeps working on its own with
/// the data saved on the phone (offline mode).
class AppState extends ChangeNotifier {
  static const _storageKey = 'gv_state_v2';
  static const _tokenKey = 'gv_token';
  static const _serverKey = 'gv_server';

  late SharedPreferences _prefs;
  late final ApiClient api;
  Timer? _poll;
  int _pendingWrites = 0;
  String _lastServerRaw = '';

  /// True when the last call to the server worked.
  bool online = false;

  /// True for a family member whose join request was accepted.
  bool connected = true;

  bool get signedIn => api.token != null;

  // Who is using the phone right now: 'rosa' (diary) or 'david' (family).
  String role = 'rosa';
  String diaryName = 'Rosa Martinez';
  String familyName = 'David Martinez';

  List<JournalEntry> entries = [];
  Map<String, DateTime?> takenAt = {};
  String takenDay = '';
  Reminder? remind; // family asked Rosa to share her day
  Reminder? medRemind; // family reminded Rosa about Metformin
  List<LoveNote> notes = []; // to Rosa
  List<FamNote> famNotes = []; // to David
  FamRequest? famRequest;
  bool famRequestSeen = true;
  List<CircleMember> circle = [];
  List<Change> changes = [];

  /// Selected bottom tab in Rosa's app (0 Talk, 1 Today, 2 Journal, 3 Circle).
  int diaryTab = 0;

  /// Selected bottom tab in David's app (0 People, 1 Updates, 2 Health, 3 Ask).
  int familyTab = 0;

  String get firstName {
    final f = diaryName.trim().split(' ').first;
    return f.isEmpty ? 'Mom' : f;
  }

  String get familyFirstName {
    final f = familyName.trim().split(' ').first;
    return f.isEmpty ? 'Family' : f;
  }

  // ---------- derived values ----------

  List<JournalEntry> get dayEntries =>
      entries.where((e) => e.kind == 'day').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<JournalEntry> get stories =>
      entries.where((e) => e.kind == 'story').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Most recent diary entry made today, if any.
  JournalEntry? get todayEntry {
    final now = DateTime.now();
    for (final e in dayEntries) {
      if (isSameDay(e.createdAt, now)) return e;
    }
    return null;
  }

  bool isTaken(String medId) => takenAt[medId] != null;

  int get takenCount => medicines.where((m) => isTaken(m.id)).length;

  // ---------- start up ----------

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    api = ApiClient(_prefs.getString(_serverKey) ?? ApiClient.defaultUrl());
    api.token = _prefs.getString(_tokenKey);

    final raw = _prefs.getString(_storageKey);
    if (raw == null) {
      _seed();
      await _save();
    } else {
      _load(jsonDecode(raw) as Map<String, dynamic>);
    }
    _rollOverDay();
    if (signedIn) {
      _startPolling();
      unawaited(refresh());
    }
  }

  void _load(Map<String, dynamic> j) {
    role = j['role'] as String? ?? role;
    diaryName = j['diaryName'] as String? ?? diaryName;
    familyName = j['familyName'] as String? ?? familyName;
    connected = j['connected'] as bool? ?? true;
    entries = (j['entries'] as List)
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    takenAt = (j['takenAt'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v == null ? null : parseTime(v as String)));
    takenDay = j['takenDay'] as String? ?? '';
    remind = j['remind'] == null ? null : Reminder.fromJson(j['remind'] as Map<String, dynamic>);
    medRemind =
        j['medRemind'] == null ? null : Reminder.fromJson(j['medRemind'] as Map<String, dynamic>);
    notes = (j['notes'] as List).map((e) => LoveNote.fromJson(e as Map<String, dynamic>)).toList();
    famNotes =
        (j['famNotes'] as List).map((e) => FamNote.fromJson(e as Map<String, dynamic>)).toList();
    famRequest = j['famRequest'] == null
        ? null
        : FamRequest.fromJson(j['famRequest'] as Map<String, dynamic>);
    famRequestSeen = j['famRequestSeen'] as bool? ?? true;
    circle = (j['circle'] as List)
        .map((e) => CircleMember.fromJson(e as Map<String, dynamic>))
        .toList();
    changes = ((j['changes'] as List?) ?? [])
        .map((e) => Change.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save() async {
    final j = {
      'role': role,
      'diaryName': diaryName,
      'familyName': familyName,
      'connected': connected,
      'entries': entries.map((e) => e.toJson()).toList(),
      'takenAt': takenAt.map((k, v) => MapEntry(k, v?.toIso8601String())),
      'takenDay': takenDay,
      'remind': remind?.toJson(),
      'medRemind': medRemind?.toJson(),
      'notes': notes.map((e) => e.toJson()).toList(),
      'famNotes': famNotes.map((e) => e.toJson()).toList(),
      'famRequest': famRequest?.toJson(),
      'famRequestSeen': famRequestSeen,
      'circle': circle.map((e) => e.toJson()).toList(),
      'changes': changes.map((e) => e.toJson()).toList(),
    };
    await _prefs.setString(_storageKey, jsonEncode(j));
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---------- server sync ----------

  void _applyServer(Map<String, dynamic> j) {
    _lastServerRaw = jsonEncode(j);
    _load(j);
    online = true;
    _changed();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => refresh());
  }

  /// Fetch the latest state from the server (called every 4 seconds).
  Future<void> refresh() async {
    if (!signedIn || _pendingWrites > 0) return;
    try {
      final j = await api.get('/state') as Map<String, dynamic>;
      if (_pendingWrites > 0) return; // a change is on its way; wait for its reply
      final wasOffline = !online;
      if (jsonEncode(j) != _lastServerRaw) {
        _applyServer(j);
      } else if (wasOffline) {
        online = true;
        notifyListeners();
      }
    } on ApiException catch (e) {
      if (e.status == 401) await _dropSession();
    } catch (_) {
      if (online) {
        online = false;
        notifyListeners();
      }
    }
  }

  /// Send a change to the server. The screen has already updated locally;
  /// the server's reply (the full state) replaces it when it arrives.
  Future<void> _remote(String method, String path, [Map<String, dynamic>? body]) async {
    if (!signedIn) return;
    _pendingWrites++;
    try {
      final j = await api.send(method, path, body ?? (method == 'POST' ? {} : null));
      _pendingWrites--;
      if (j is Map<String, dynamic> && j.containsKey('entries')) _applyServer(j);
    } on ApiException catch (e) {
      _pendingWrites--;
      if (e.status == 401) await _dropSession();
      debugPrint('API $path: ${e.message}');
    } catch (e) {
      _pendingWrites--;
      online = false;
      notifyListeners();
      debugPrint('API $path offline: $e');
    }
  }

  Future<void> _dropSession() async {
    api.token = null;
    online = false;
    _poll?.cancel();
    await _prefs.remove(_tokenKey);
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    api.baseUrl = url.trim();
    await _prefs.setString(_serverKey, api.baseUrl);
    notifyListeners();
  }

  /// Returns Claude/model info if the server answers, or null.
  Future<Map<String, dynamic>?> checkServer() async {
    try {
      final j = await api.get('/health') as Map<String, dynamic>;
      return j;
    } catch (_) {
      return null;
    }
  }

  // ---------- sign in / sign up ----------

  Future<AuthResult> login(String email, String password) =>
      _auth('/auth/login', {'email': email.trim(), 'password': password},
          offlineRole: email.trim().toLowerCase().startsWith('david') ? 'david' : 'rosa');

  Future<AuthResult> signup({
    required String name,
    required String email,
    required String password,
    required bool diary,
  }) {
    if (diary) {
      diaryName = name.trim();
    } else {
      familyName = name.trim();
    }
    return _auth(
      '/auth/signup',
      {'name': name.trim(), 'email': email.trim(), 'password': password, 'role': diary ? 'diary' : 'family'},
      offlineRole: diary ? 'rosa' : 'david',
    );
  }

  Future<AuthResult> _auth(String path, Map<String, dynamic> body, {required String offlineRole}) async {
    try {
      final j = await api.post(path, body) as Map<String, dynamic>;
      api.token = j['token'] as String;
      await _prefs.setString(_tokenKey, api.token!);
      role = j['role'] as String;
      _applyServer(j['state'] as Map<String, dynamic>);
      _startPolling();
      return const AuthResult.ok();
    } on ApiException catch (e) {
      return AuthResult.error(e.message);
    } catch (_) {
      // Server not reachable: carry on with the data on this phone.
      online = false;
      role = offlineRole;
      _changed();
      return const AuthResult.offline();
    }
  }

  Future<void> signOut() async {
    if (signedIn) {
      try {
        await api.post('/auth/logout');
      } catch (_) {}
    }
    await _dropSession();
  }

  // ---------- AI (server only) ----------

  /// Claude reads the transcript. Null when offline.
  Future<Map<String, dynamic>?> analyze(String text) async {
    if (!signedIn) return null;
    try {
      return await api.post('/analyze', {'text': text}) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> digest() async {
    if (!signedIn) return null;
    try {
      return await api.get('/digest') as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> ask(String question) async {
    if (!signedIn) return null;
    try {
      return await api.post('/ask', {'question': question}) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ---------- local sample data ----------

  /// Sample data so the journal is not empty on first launch (offline mode).
  /// Dates are relative to today so "Yesterday" etc. always read correctly.
  void _seed() {
    final today = dayOnly(DateTime.now());
    DateTime at(int daysAgo, int h, int m) =>
        today.subtract(Duration(days: daysAgo)).add(Duration(hours: h, minutes: m));

    entries = [
      JournalEntry(
        id: 'seed1',
        createdAt: at(1, 19, 40),
        shared: false,
        text: "Quiet evening. I miss Walter's piano on nights like this. "
            'He used to play Moon River after dinner. The house feels very still now.',
      ),
      JournalEntry(
        id: 'seed2',
        createdAt: at(1, 9, 5),
        shared: true,
        text: 'Walked to the garden with Linda. Tomatoes are finally red. '
            'We picked six. Linda is making sauce on Saturday.',
      ),
      JournalEntry(
        id: 'seed3',
        createdAt: at(3, 18, 20),
        shared: true,
        flags: ['dizzy'],
        text: 'Maya called. She got the part in the school play. She is going '
            'to be the narrator. I will sit in the front row. '
            'Felt a little dizzy after lunch but it passed when I sat down.',
      ),
      JournalEntry(
        id: 'story1',
        kind: 'story',
        title: 'How I met Walter',
        createdAt: at(15, 16, 0),
        shared: true,
        text: 'It was a church dance in 1968. He stepped on my foot twice '
            'and apologised so sweetly that I agreed to a second dance.',
      ),
      JournalEntry(
        id: 'story2',
        kind: 'story',
        title: 'Our first winter in Chicago',
        createdAt: at(22, 16, 0),
        shared: true,
        text: 'We had one coat between us that first winter and took turns '
            'wearing it to the bus stop.',
      ),
      JournalEntry(
        id: 'story3',
        kind: 'story',
        title: "Sunday dinners at Mama's",
        createdAt: at(29, 16, 0),
        shared: true,
        text: 'Every Sunday the whole family squeezed into Mama\'s kitchen. '
            'There was always more food than chairs.',
      ),
    ];
    circle = [
      CircleMember(name: 'David', relation: 'Son'),
      CircleMember(name: 'Maya', relation: 'Granddaughter'),
      CircleMember(name: 'ana.r@example.com', relation: 'Caregiver', pending: true),
    ];
    notes = [];
    famNotes = [];
    changes = [];
    remind = null;
    medRemind = null;
    famRequest = null;
    takenDay = '';
    connected = true;
  }

  /// New day: reset medicines and the day's reminders (offline mode; the
  /// server does the same for signed-in users).
  void _rollOverDay() {
    final todayKey = dayOnly(DateTime.now()).toIso8601String();
    if (takenDay == todayKey || signedIn) return;
    final morning = dayOnly(DateTime.now()).add(const Duration(hours: 8, minutes: 12));
    // Demo default: the two 8 AM medicines were already taken.
    takenAt = {'l': morning, 'v': morning, 'm': null, 'a': null};
    takenDay = todayKey;
    remind = null;
    medRemind = null;
    _save();
  }

  /// Restore the sample data here and on the server. Signs out, because the
  /// server forgets all logins when it resets.
  Future<void> resetDemo() async {
    try {
      await api.post('/demo/reset');
    } catch (_) {}
    await _dropSession();
    await _prefs.remove(_storageKey);
    final keepRole = role;
    _seed();
    role = keepRole;
    diaryName = 'Rosa Martinez';
    familyName = 'David Martinez';
    _rollOverDay();
    _changed();
  }

  // ---------- actions ----------
  // Each one updates the screen right away, then tells the server.

  void setRole(String r) {
    role = r;
    _changed();
  }

  void setDiaryTab(int i) {
    diaryTab = i;
    notifyListeners();
  }

  void setFamilyTab(int i) {
    familyTab = i;
    notifyListeners();
  }

  void setDiaryName(String name) {
    if (name.trim().isEmpty) return;
    diaryName = name.trim();
    _changed();
  }

  void setFamilyName(String name) {
    if (name.trim().isEmpty) return;
    familyName = name.trim();
    _changed();
  }

  /// Save a diary entry with the current date and time.
  void addEntry({
    required String text,
    required bool shared,
    required int durationSeconds,
    List<Update> updates = const [],
    List<String> flags = const [],
  }) {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    entries.add(JournalEntry(
      id: id,
      text: text,
      createdAt: now,
      shared: shared,
      durationSeconds: durationSeconds,
      flags: flags,
    ));
    for (final u in updates) {
      changes.insert(0, Change(u.title, u.kind, now));
    }
    remind = null;
    famNotes.insert(
        0, FamNote(shared ? '$firstName shared her day' : '$firstName journaled (private)', now));
    _changed();
    _remote('POST', '/entries', {
      'id': id,
      'text': text,
      'shared': shared,
      'duration_seconds': durationSeconds,
      'updates': updates.map((u) => u.toJson()).toList(),
      'flags': flags,
    });
  }

  void deleteEntry(String id) {
    entries.removeWhere((e) => e.id == id);
    _changed();
    _remote('DELETE', '/entries/$id');
  }

  void toggleShared(String id) {
    final i = entries.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = entries[i];
    entries[i] = JournalEntry(
      id: e.id,
      text: e.text,
      createdAt: e.createdAt,
      shared: !e.shared,
      kind: e.kind,
      title: e.title,
      durationSeconds: e.durationSeconds,
      flags: e.flags,
    );
    _changed();
    _remote('PATCH', '/entries/$id', {'shared': !e.shared});
  }

  void addStory({required String title, required String text, required int durationSeconds}) {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    entries.add(JournalEntry(
      id: id,
      kind: 'story',
      title: title,
      text: text,
      createdAt: now,
      shared: true,
      durationSeconds: durationSeconds,
    ));
    famNotes.insert(0, FamNote('Mom added a Life Story: $title', now));
    _changed();
    _remote('POST', '/stories',
        {'id': id, 'title': title, 'text': text, 'duration_seconds': durationSeconds});
  }

  void setTaken(String medId, bool taken) {
    final med = medicines.firstWhere((m) => m.id == medId);
    takenAt[medId] = taken ? DateTime.now() : null;
    if (taken) {
      famNotes.insert(0, FamNote('$firstName took ${med.name}', DateTime.now()));
      if (medId == 'm') medRemind = null;
    }
    _changed();
    _remote('POST', '/doses', {'med_id': medId, 'taken': taken});
  }

  void sendRemind() {
    remind ??= Reminder(familyFirstName, DateTime.now());
    _changed();
    _remote('POST', '/reminders', {'kind': 'day'});
  }

  void sendMedRemind() {
    medRemind ??= Reminder(familyFirstName, DateTime.now());
    _changed();
    _remote('POST', '/reminders', {'kind': 'med'});
  }

  void sendLove() {
    notes.insert(0, LoveNote(kind: 'love', text: '$familyFirstName sent you love', at: DateTime.now()));
    _changed();
    _remote('POST', '/notes', {'kind': 'love'});
  }

  void sendVoice(String words) {
    notes.insert(
        0,
        LoveNote(
          kind: 'voice',
          text: 'Voice message from $familyFirstName',
          at: DateTime.now(),
          say: words,
        ));
    _changed();
    _remote('POST', '/notes', {'kind': 'voice', 'say': words});
  }

  void thankLatestNote() {
    if (notes.isEmpty || notes.first.thanked) return;
    notes[0] = notes.first.copyWith(thanked: true);
    famNotes.insert(0, FamNote('$firstName says thank you, dear', DateTime.now()));
    _changed();
    _remote('POST', '/notes/thank');
  }

  void loveBack() {
    if (notes.isEmpty || notes.first.lovedBack) return;
    notes[0] = notes.first.copyWith(lovedBack: true, thanked: true);
    famNotes.insert(0, FamNote('Mom sent love back', DateTime.now()));
    _changed();
    _remote('POST', '/notes/love-back');
  }

  /// Family member asks to join a diary keeper's circle. Returns an error
  /// message from the server (e.g. unknown email), or null.
  Future<String?> sendFamRequest({required String name, required String contact, required String rel}) async {
    famRequest = FamRequest(from: familyFirstName, name: name, rel: rel, at: DateTime.now());
    famRequestSeen = false;
    _changed();
    if (!signedIn) return null;
    try {
      final j = await api.post('/fam-requests', {'name': name, 'contact': contact, 'rel': rel});
      _applyServer(j as Map<String, dynamic>);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return null;
    }
  }

  void answerFamRequest(bool accept) {
    final r = famRequest;
    if (r == null) return;
    famRequest = r.respond(accept ? 'accepted' : 'declined');
    if (accept && !circle.any((c) => c.name == r.from)) {
      circle.insert(0, CircleMember(name: r.from, relation: 'Son'));
    }
    _changed();
    _remote('POST', '/fam-requests/answer', {'accept': accept});
  }

  void markFamRequestSeen() {
    if (famRequestSeen) return;
    famRequestSeen = true;
    _changed();
    _remote('POST', '/fam-requests/seen');
  }

  void invite(String email, String relation) {
    circle.add(CircleMember(name: email, relation: relation, pending: true));
    _changed();
    _remote('POST', '/circle', {'email': email, 'relation': relation});
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
