import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifier.dart';

class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();

  // ---- settings ----
  final ValueNotifier<String> lang = ValueNotifier('ar');
  final ValueNotifier<double> fontScale = ValueNotifier(1.0);
  final ValueNotifier<int> accent = ValueNotifier(0xFFFF8A00);
  final ValueNotifier<bool> bgGray = ValueNotifier(false);
  String sortMode = 'newest'; // newest | oldest | updated | az
  bool listView = false;
  bool backupReminder = true;
  bool appLock = false;

  // ---- data ----
  List<Note> notes = [];
  List<Notebook> notebooks = [];
  List<TaskItem> tasks = [];
  List<Idea> ideas = [];
  late SharedPreferences _p;
  late Directory _attachDir;

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
  static int newNotifId() =>
      (DateTime.now().microsecondsSinceEpoch ~/ 1000) % 2147483647;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final docs = await getApplicationDocumentsDirectory();
    _attachDir = Directory('${docs.path}/attachments');
    await _attachDir.create(recursive: true);

    lang.value = _p.getString('lang') ?? 'ar';
    fontScale.value = _p.getDouble('fontScale') ?? 1.0;
    accent.value = _p.getInt('accent') ?? 0xFFFF8A00;
    bgGray.value = _p.getBool('bgGray') ?? false;
    sortMode = _p.getString('sortMode') ?? 'newest';
    listView = _p.getBool('listView') ?? false;
    backupReminder = _p.getBool('backupReminder') ?? true;
    appLock = _p.getBool('appLock') ?? false;

    notes = _decode(_p.getString('notes'), Note.fromJson);
    notebooks = _decode(_p.getString('notebooks'), Notebook.fromJson);
    tasks = _decode(_p.getString('tasks'), TaskItem.fromJson);
    ideas = _decode(_p.getString('ideas'), Idea.fromJson);
    await purgeExpired();
  }

  /// Re-reads tasks from disk (a notification button may have changed them
  /// while the app was closed).
  Future<void> reloadTasks() async {
    await _p.reload();
    tasks = _decode(_p.getString('tasks'), TaskItem.fromJson);
    notifyListeners();
  }

  List<T> _decode<T>(String? s, T Function(Map<String, dynamic>) f) {
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => f(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---- setters for settings ----
  Future<void> setLang(String l) async {
    lang.value = l;
    await _p.setString('lang', l);
  }

  Future<void> setFontScale(double v) async {
    fontScale.value = v;
    await _p.setDouble('fontScale', v);
  }

  Future<void> setAccent(int c) async {
    accent.value = c;
    await _p.setInt('accent', c);
  }

  Future<void> setBgGray(bool v) async {
    bgGray.value = v;
    await _p.setBool('bgGray', v);
  }

  Future<void> setSortMode(String m) async {
    sortMode = m;
    await _p.setString('sortMode', m);
    notifyListeners();
  }

  Future<void> setListView(bool v) async {
    listView = v;
    await _p.setBool('listView', v);
    notifyListeners();
  }

  Future<void> setAppLock(bool v) async {
    appLock = v;
    await _p.setBool('appLock', v);
    notifyListeners();
  }

  Future<void> setBackupReminder(bool v) async {
    backupReminder = v;
    await _p.setBool('backupReminder', v);
    await Notifier.setBackupReminder(v, lang: lang.value);
    notifyListeners();
  }

  // ---- attachment files ----
  String get attachDirPath => _attachDir.path;
  File fileOf(Attachment a) => File('${_attachDir.path}/${a.file}');
  String newAttachPath(String ext) => '${_attachDir.path}/${newId()}.$ext';

  Future<void> deleteFiles(Iterable<Attachment> list) async {
    for (final a in list) {
      try {
        final f = fileOf(a);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Persists every list (used after a restore).
  Future<void> saveAll() async {
    await _saveNotes();
    await _saveNotebooks();
    await saveTasks();
    await saveIdeas();
  }

  // ---- notebooks ----
  Notebook? notebookById(String? id) {
    if (id == null) return null;
    for (final b in notebooks) {
      if (b.id == id) return b;
    }
    return null;
  }

  int countIn(String? notebookId) => activeNotes
      .where((n) => notebookId == null
          ? n.notebooks.isEmpty
          : n.notebooks.contains(notebookId))
      .length;

  Future<void> upsertNotebook(Notebook b) async {
    final idx = notebooks.indexWhere((e) => e.id == b.id);
    if (idx >= 0) {
      notebooks[idx] = b;
    } else {
      notebooks.add(b);
    }
    notebooks.sort((a, b) => a.created.compareTo(b.created));
    await _saveNotebooks();
  }

  /// Deleting a notebook keeps its notes (removed from that notebook only).
  Future<void> deleteNotebook(String id) async {
    notebooks.removeWhere((e) => e.id == id);
    for (final n in notes) {
      n.notebooks = n.notebooks.where((e) => e != id).toList();
    }
    await _saveNotes();
    await _saveNotebooks();
  }

  Future<void> _saveNotebooks() async {
    notifyListeners();
    await _p.setString(
        'notebooks', jsonEncode(notebooks.map((e) => e.toJson()).toList()));
  }

  // ---- notes ----
  List<Note> get activeNotes => notes.where((n) => n.isActive).toList();
  List<Note> get archivedNotes =>
      notes.where((n) => n.archived && !n.inTrash).toList();
  List<Note> get trashedNotes => notes.where((n) => n.inTrash).toList();

  Note? noteById(String id) {
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  Future<void> upsertNote(Note n) async {
    final idx = notes.indexWhere((e) => e.id == n.id);
    if (idx >= 0) {
      notes[idx] = n;
    } else {
      notes.add(n);
    }
    await _saveNotes();
  }

  /// Hard delete (also removes the attached files).
  Future<void> deleteNote(String id) async {
    final matches = notes.where((e) => e.id == id).toList();
    notes.removeWhere((e) => e.id == id);
    for (final n in matches) {
      await deleteFiles(n.attachments);
    }
    await _saveNotes();
  }

  Future<void> trashNote(Note n) async {
    n.deletedAt = DateTime.now();
    n.pinned = false;
    await _saveNotes();
  }

  Future<void> restoreNote(Note n) async {
    n.deletedAt = null;
    await _saveNotes();
  }

  Future<void> setArchived(Note n, bool v) async {
    n.archived = v;
    if (v) n.pinned = false;
    await _saveNotes();
  }

  Future<void> emptyTrash() async {
    for (final n in trashedNotes) {
      await deleteNote(n.id);
    }
  }

  /// Notes stay in the trash for 30 days.
  Future<void> purgeExpired() async {
    final limit = DateTime.now().subtract(const Duration(days: 30));
    final old = notes
        .where((n) => n.deletedAt != null && n.deletedAt!.isBefore(limit))
        .map((n) => n.id)
        .toList();
    for (final id in old) {
      await deleteNote(id);
    }
  }

  /// Pinned first, then by the chosen sort mode.
  List<Note> sorted(Iterable<Note> list) {
    final l = list.toList();
    int cmp(Note a, Note b) {
      switch (sortMode) {
        case 'oldest':
          return a.created.compareTo(b.created);
        case 'updated':
          return b.updated.compareTo(a.updated);
        case 'az':
          String key(Note n) =>
              (n.title.isNotEmpty ? n.title : n.plain).toLowerCase();
          return key(a).compareTo(key(b));
        default:
          return b.created.compareTo(a.created);
      }
    }

    l.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return cmp(a, b);
    });
    return l;
  }

  Future<void> _saveNotes() async {
    notifyListeners();
    await _p.setString(
        'notes', jsonEncode(notes.map((e) => e.toJson()).toList()));
  }

  // ---- tasks ----
  Future<void> upsertTask(TaskItem t) async {
    final idx = tasks.indexWhere((e) => e.id == t.id);
    if (idx >= 0) {
      tasks[idx] = t;
    } else {
      tasks.insert(0, t);
    }
    await saveTasks();
    await Notifier.sync(t);
  }

  /// Completing a repeating task moves it to its next occurrence instead.
  /// Returns the next date for repeating tasks, otherwise null.
  Future<DateTime?> toggleTask(TaskItem t) async {
    DateTime? next;
    if (!t.done && t.repeats) {
      next = t.nextAfter(DateTime.now());
      t.remind = next;
      for (final s in t.subtasks) {
        s.done = false;
      }
    } else {
      t.done = !t.done;
    }
    await saveTasks();
    await Notifier.sync(t);
    return next;
  }

  Future<void> deleteTask(TaskItem t) async {
    tasks.removeWhere((e) => e.id == t.id);
    await saveTasks();
    await Notifier.cancel(t.notifId);
  }

  Future<void> saveTasks() async {
    notifyListeners();
    await _p.setString(
        'tasks', jsonEncode(tasks.map((e) => e.toJson()).toList()));
  }

  // ---- ideas ----
  Future<void> upsertIdea(Idea n) async {
    final idx = ideas.indexWhere((e) => e.id == n.id);
    if (idx >= 0) {
      ideas[idx] = n;
    } else {
      ideas.add(n);
    }
    await saveIdeas();
  }

  Future<void> deleteIdea(String id) async {
    ideas.removeWhere((e) => e.id == id);
    await saveIdeas();
  }

  Future<void> saveIdeas() async {
    notifyListeners();
    await _p.setString(
        'ideas', jsonEncode(ideas.map((e) => e.toJson()).toList()));
  }
}
