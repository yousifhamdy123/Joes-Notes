class Note {
  String id;
  String delta; // Quill delta as JSON string
  String plain; // plain text, used for search + preview
  DateTime created;
  DateTime updated;

  Note({
    required this.id,
    required this.delta,
    required this.plain,
    required this.created,
    required this.updated,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'delta': delta,
        'plain': plain,
        'created': created.toIso8601String(),
        'updated': updated.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'],
        delta: j['delta'],
        plain: j['plain'] ?? '',
        created: DateTime.parse(j['created']),
        updated: DateTime.parse(j['updated']),
      );
}

class TaskItem {
  String id;
  int notifId;
  String title;
  String note;
  bool done;
  DateTime? remind;
  DateTime created;

  TaskItem({
    required this.id,
    required this.notifId,
    required this.title,
    this.note = '',
    this.done = false,
    this.remind,
    required this.created,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'notifId': notifId,
        'title': title,
        'note': note,
        'done': done,
        'remind': remind?.toIso8601String(),
        'created': created.toIso8601String(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'],
        notifId: j['notifId'],
        title: j['title'],
        note: j['note'] ?? '',
        done: j['done'] ?? false,
        remind: j['remind'] == null ? null : DateTime.parse(j['remind']),
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
