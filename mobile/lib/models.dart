/// Plain data classes. Every class converts to/from JSON so AppState can
/// save everything to the phone with shared_preferences.
library;

/// Parses a date from the phone cache or the server (which sends a UTC
/// offset, e.g. +05:30) and shows it in the phone's own time zone.
DateTime parseTime(String s) => DateTime.parse(s).toLocal();

class JournalEntry {
  JournalEntry({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.shared,
    this.kind = 'day',
    this.title,
    this.durationSeconds = 0,
    this.flags = const [],
  });

  final String id;
  final String text;
  final DateTime createdAt; // stored in local time as ISO-8601
  final bool shared;
  final String kind; // 'day' (daily journal) or 'story' (Life Story)
  final String? title; // Life Story title
  final int durationSeconds;
  final List<String> flags; // e.g. ['dizzy'], noticed in what she said

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'shared': shared,
        'kind': kind,
        'title': title,
        'durationSeconds': durationSeconds,
        'flags': flags,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'] as String,
        text: j['text'] as String,
        createdAt: parseTime(j['createdAt'] as String),
        shared: j['shared'] as bool? ?? false,
        kind: j['kind'] as String? ?? 'day',
        title: j['title'] as String?,
        durationSeconds: j['durationSeconds'] as int? ?? 0,
        flags: (j['flags'] as List?)?.cast<String>() ?? const [],
      );
}

/// "David is thinking of you" style reminder, or a medicine reminder.
class Reminder {
  Reminder(this.who, this.at);
  final String who;
  final DateTime at;

  Map<String, dynamic> toJson() => {'who': who, 'at': at.toIso8601String()};
  factory Reminder.fromJson(Map<String, dynamic> j) =>
      Reminder(j['who'] as String, parseTime(j['at'] as String));
}

/// A note from family to Rosa: love or a voice message.
class LoveNote {
  LoveNote({
    required this.kind,
    required this.text,
    required this.at,
    this.say,
    this.thanked = false,
    this.lovedBack = false,
  });

  final String kind; // 'love' | 'voice'
  final String text;
  final DateTime at;
  final String? say; // words read aloud for a voice message
  final bool thanked;
  final bool lovedBack;

  LoveNote copyWith({bool? thanked, bool? lovedBack}) => LoveNote(
        kind: kind,
        text: text,
        at: at,
        say: say,
        thanked: thanked ?? this.thanked,
        lovedBack: lovedBack ?? this.lovedBack,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'text': text,
        'at': at.toIso8601String(),
        'say': say,
        'thanked': thanked,
        'lovedBack': lovedBack,
      };

  factory LoveNote.fromJson(Map<String, dynamic> j) => LoveNote(
        kind: j['kind'] as String,
        text: j['text'] as String,
        at: parseTime(j['at'] as String),
        say: j['say'] as String?,
        thanked: j['thanked'] as bool? ?? false,
        lovedBack: j['lovedBack'] as bool? ?? false,
      );
}

/// Activity David sees ("Rosa took Metformin").
class FamNote {
  FamNote(this.text, this.at);
  final String text;
  final DateTime at;

  Map<String, dynamic> toJson() => {'text': text, 'at': at.toIso8601String()};
  factory FamNote.fromJson(Map<String, dynamic> j) =>
      FamNote(j['text'] as String, parseTime(j['at'] as String));
}

/// David asking to join Rosa's circle.
class FamRequest {
  FamRequest({
    required this.from,
    required this.name,
    required this.rel,
    required this.at,
    this.status = 'pending',
    this.respondedAt,
  });

  final String from;
  final String name;
  final String rel;
  final DateTime at;
  final String status; // pending | accepted | declined
  final DateTime? respondedAt;

  FamRequest respond(String newStatus) => FamRequest(
        from: from,
        name: name,
        rel: rel,
        at: at,
        status: newStatus,
        respondedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'from': from,
        'name': name,
        'rel': rel,
        'at': at.toIso8601String(),
        'status': status,
        'respondedAt': respondedAt?.toIso8601String(),
      };

  factory FamRequest.fromJson(Map<String, dynamic> j) => FamRequest(
        from: j['from'] as String,
        name: j['name'] as String,
        rel: j['rel'] as String,
        at: parseTime(j['at'] as String),
        status: j['status'] as String? ?? 'pending',
        respondedAt: j['respondedAt'] == null
            ? null
            : parseTime(j['respondedAt'] as String),
      );
}

class CircleMember {
  CircleMember({required this.name, required this.relation, this.pending = false});
  final String name;
  final String relation;
  final bool pending;

  Map<String, dynamic> toJson() =>
      {'name': name, 'relation': relation, 'pending': pending};
  factory CircleMember.fromJson(Map<String, dynamic> j) => CircleMember(
        name: j['name'] as String,
        relation: j['relation'] as String,
        pending: j['pending'] as bool? ?? false,
      );
}

/// Something the app picked up from what Rosa said: a medicine change or
/// a calendar event. Shown on the review screen as a checkbox.
class Update {
  Update({required this.title, required this.kind});
  final String title;
  final String kind; // 'Medicine change' | 'Calendar'

  Map<String, dynamic> toJson() => {'title': title, 'kind': kind};
  factory Update.fromJson(Map<String, dynamic> j) =>
      Update(title: j['title'] as String, kind: j['kind'] as String);
}

/// A saved update with the date it was confirmed.
class Change {
  Change(this.title, this.kind, this.at);
  final String title;
  final String kind;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'title': title, 'kind': kind, 'at': at.toIso8601String()};
  factory Change.fromJson(Map<String, dynamic> j) => Change(
      j['title'] as String, j['kind'] as String, parseTime(j['at'] as String));
}

class Medicine {
  const Medicine(this.id, this.time, this.name, this.dose);
  final String id;
  final String time;
  final String name;
  final String dose;
}

const medicines = [
  Medicine('l', '8:00 AM', 'Lisinopril', '10 mg'),
  Medicine('v', '8:00 AM', 'Vitamin D', '1000 IU'),
  Medicine('m', '12:30 PM', 'Metformin', '500 mg, with food'),
  Medicine('a', '9:00 PM', 'Atorvastatin', '20 mg'),
];
