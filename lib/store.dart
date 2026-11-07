import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifier.dart';

class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();

  final ValueNotifier<String> lang = ValueNotifier('ar');
  List<Note> notes = [];
  List<TaskItem> tasks = [];
  List<Idea> ideas = [];
  late SharedPreferences _p;

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
  static int newNotifId() =>
      (DateTime.now().microsecondsSinceEpoch ~/ 1000) % 2147483647;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    lang.value = _p.getString('lang') ?? 'ar';
    notes = _decode(_p.getString('notes'), Note.fromJson);
    tasks = _decode(_p.getString('tasks'), TaskItem.fromJson);
    ideas = _decode(_p.getString('ideas'), Idea.fromJson);
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

  Future<void> setLang(String l) async {
    lang.value = l;
    await _p.setString('lang', l);
  }

  // ---- notes ----
  Future<void> upsertNote(Note n) async {
    final idx = notes.indexWhere((e) => e.id == n.id);
    if (idx >= 0) {
      notes[idx] = n;
    } else {
      notes.add(n);
    }
    notes.sort((a, b) => b.created.compareTo(a.created));
    await _saveNotes();
  }

  Future<void> deleteNote(String id) async {
    notes.removeWhere((e) => e.id == id);
    await _saveNotes();
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
    await _saveTasks();
    await Notifier.sync(t);
  }

  Future<void> toggleTask(TaskItem t) async {
    t.done = !t.done;
    await _saveTasks();
    await Notifier.sync(t);
  }

  Future<void> deleteTask(TaskItem t) async {
    tasks.removeWhere((e) => e.id == t.id);
    await _saveTasks();
    await Notifier.cancel(t.notifId);
  }

  Future<void> _saveTasks() async {
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
