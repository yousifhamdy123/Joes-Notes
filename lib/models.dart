class Attachment {
  String id;
  String type; // 'image' | 'audio'
  String file; // file name inside the app's attachments folder
  int durationMs;
  String name; // user's label for a recording ('' = default)
  // For recordings made while typing: [startIndex, endIndex, ms] per word.
  List<List<int>> marks;

  Attachment({
    required this.id,
    required this.type,
    required this.file,
    this.durationMs = 0,
    this.name = '',
    List<List<int>>? marks,
  }) : marks = marks ?? [];

  bool get isImage => type == 'image';
  bool get isAudio => type == 'audio';

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'file': file,
        'durationMs': durationMs,
        'name': name,
        'marks': marks,
      };

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'],
        type: j['type'],
        file: j['file'],
        durationMs: j['durationMs'] ?? 0,
        name: j['name'] ?? '',
        marks: ((j['marks'] ?? const []) as List)
            .map((e) => List<int>.from(e as List))
            .toList(),
      );
}

class Notebook {
  String id;
  String name;
  DateTime created;

  Notebook({required this.id, required this.name, required this.created});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'created': created.toIso8601String()};

  factory Notebook.fromJson(Map<String, dynamic> j) => Notebook(
        id: j['id'],
        name: j['name'],
        created: DateTime.parse(j['created']),
      );
}

class Note {
  String id;
  String title;
  String delta; // Quill delta as JSON string
  String plain; // plain text, used for search + preview
  List<String> keywords;
  List<String> notebooks; // notebook ids (a note can be in several)
  List<Attachment> attachments;
  bool pinned;
  int color; // 0 = default card
  bool archived;
  bool locked;
  DateTime? deletedAt; // non-null = in trash
  DateTime created;
  DateTime updated;

  Note({
    required this.id,
    this.title = '',
    required this.delta,
    required this.plain,
    this.keywords = const [],
    this.notebooks = const [],
    this.attachments = const [],
    this.pinned = false,
    this.color = 0,
    this.archived = false,
    this.locked = false,
    this.deletedAt,
    required this.created,
    required this.updated,
  });

  bool get inTrash => deletedAt != null;
  bool get isActive => !archived && deletedAt == null;

  int get imageCount => attachments.where((e) => e.isImage).length;
  int get audioCount => attachments.where((e) => e.isAudio).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'delta': delta,
        'plain': plain,
        'keywords': keywords,
        'notebooks': notebooks,
        'attachments': attachments.map((e) => e.toJson()).toList(),
        'pinned': pinned,
        'color': color,
        'archived': archived,
        'locked': locked,
        'deletedAt': deletedAt?.toIso8601String(),
        'created': created.toIso8601String(),
        'updated': updated.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'],
        title: j['title'] ?? '',
        delta: j['delta'],
        plain: j['plain'] ?? '',
        keywords: List<String>.from(j['keywords'] ?? const []),
        notebooks: [
          ...List<String>.from(j['notebooks'] ?? const []),
          if (j['notebookId'] != null) j['notebookId'] as String,
        ],
        attachments: ((j['attachments'] ?? const []) as List)
            .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        pinned: j['pinned'] ?? false,
        color: j['color'] ?? 0,
        archived: j['archived'] ?? false,
        locked: j['locked'] ?? false,
        deletedAt:
            j['deletedAt'] == null ? null : DateTime.parse(j['deletedAt']),
        created: DateTime.parse(j['created']),
        updated: DateTime.parse(j['updated']),
      );
}

class SubTask {
  String title;
  bool done;
  SubTask({required this.title, this.done = false});

  Map<String, dynamic> toJson() => {'title': title, 'done': done};
  factory SubTask.fromJson(Map<String, dynamic> j) =>
      SubTask(title: j['title'] ?? '', done: j['done'] ?? false);
}

class TaskItem {
  String id;
  int notifId;
  String title;
  String note;
  bool done;
  DateTime? remind;
  String repeat; // none | daily | weekly | monthly
  int priority; // 0 normal, 1 low, 2 medium, 3 high
  List<SubTask> subtasks;
  DateTime created;

  TaskItem({
    required this.id,
    required this.notifId,
    required this.title,
    this.note = '',
    this.done = false,
    this.remind,
    this.repeat = 'none',
    this.priority = 0,
    this.subtasks = const [],
    required this.created,
  });

  bool get repeats => repeat != 'none' && remind != null;

  /// The next occurrence strictly after [from] for a repeating task.
  DateTime? nextAfter(DateTime from) {
    var d = remind;
    if (d == null || repeat == 'none') return null;
    var guard = 0;
    while (!d!.isAfter(from) && guard++ < 2000) {
      switch (repeat) {
        case 'daily':
          d = DateTime(d.year, d.month, d.day + 1, d.hour, d.minute);
          break;
        case 'weekly':
          d = DateTime(d.year, d.month, d.day + 7, d.hour, d.minute);
          break;
        default:
          d = DateTime(d.year, d.month + 1, d.day, d.hour, d.minute);
      }
    }
    return d;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notifId': notifId,
        'title': title,
        'note': note,
        'done': done,
        'remind': remind?.toIso8601String(),
        'repeat': repeat,
        'priority': priority,
        'subtasks': subtasks.map((e) => e.toJson()).toList(),
        'created': created.toIso8601String(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'],
        notifId: j['notifId'],
        title: j['title'],
        note: j['note'] ?? '',
        done: j['done'] ?? false,
        remind: j['remind'] == null ? null : DateTime.parse(j['remind']),
        repeat: j['repeat'] ?? 'none',
        priority: j['priority'] ?? 0,
        subtasks: ((j['subtasks'] ?? const []) as List)
            .map((e) => SubTask.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        created: DateTime.parse(j['created']),
      );
}

class Idea {
  String id;
  String text;
  int color; // sticky background (ARGB)
  int textColor;
  String font;
  double size;
  bool bold;
  bool italic;
  double x; // 0..1 fraction of free width
  double y; // px from top
  double angle; // radians

  Idea({
    required this.id,
    this.text = '',
    this.color = 0xFFFFF59D,
    this.textColor = 0xFF000000,
    this.font = 'sans-serif',
    this.size = 18,
    this.bold = false,
    this.italic = false,
    this.x = 0.05,
    this.y = 20,
    this.angle = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'color': color,
        'textColor': textColor,
        'font': font,
        'size': size,
        'bold': bold,
        'italic': italic,
        'x': x,
        'y': y,
        'angle': angle,
      };

  factory Idea.fromJson(Map<String, dynamic> j) => Idea(
        id: j['id'],
        text: j['text'] ?? '',
        color: j['color'],
        textColor: j['textColor'],
        font: j['font'],
        size: (j['size'] as num).toDouble(),
        bold: j['bold'] ?? false,
        italic: j['italic'] ?? false,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        angle: (j['angle'] as num).toDouble(),
      );
}
