import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';
import 'models.dart';
import 'notifier.dart';
import 'store.dart';
import 'widgets.dart';

const _kApp = 'joes_notes';

/// Builds one zip: data.json + every attached image / recording.
Future<Uint8List> buildBackup() async {
  final s = Store.i;
  final data = {
    'app': _kApp,
    'version': 1,
    'exported': DateTime.now().toIso8601String(),
    'notes': s.notes.map((e) => e.toJson()).toList(),
    'notebooks': s.notebooks.map((e) => e.toJson()).toList(),
    'tasks': s.tasks.map((e) => e.toJson()).toList(),
    'ideas': s.ideas.map((e) => e.toJson()).toList(),
  };
  final arc = Archive();
  final json = utf8.encode(jsonEncode(data));
  arc.addFile(ArchiveFile('data.json', json.length, json));
  for (final n in s.notes) {
    for (final a in n.attachments) {
      final f = s.fileOf(a);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        arc.addFile(ArchiveFile('media/${a.file}', bytes.length, bytes));
      }
    }
  }
  final out = ZipEncoder().encode(arc);
  return Uint8List.fromList(out!);
}

class RestoreResult {
  int notes = 0, notebooks = 0, tasks = 0, ideas = 0;
  bool get nothing => notes + notebooks + tasks + ideas == 0;
}

/// Merges a backup into the current data. Items whose id already exists are
/// kept as they are; nothing is ever deleted.
Future<RestoreResult> restoreBackup(Uint8List bytes) async {
  final s = Store.i;
  final arc = ZipDecoder().decodeBytes(bytes);
  final entry = arc.findFile('data.json');
  if (entry == null) throw const FormatException('no data.json');
  final data = jsonDecode(utf8.decode(entry.content as List<int>))
      as Map<String, dynamic>;
  if (data['app'] != _kApp) throw const FormatException('wrong app');

  List<Map<String, dynamic>> list(String k) => ((data[k] ?? const []) as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  final r = RestoreResult();

  final nbIds = s.notebooks.map((e) => e.id).toSet();
  for (final j in list('notebooks')) {
    final nb = Notebook.fromJson(j);
    if (nbIds.add(nb.id)) {
      s.notebooks.add(nb);
      r.notebooks++;
    }
  }

  final noteIds = s.notes.map((e) => e.id).toSet();
  for (final j in list('notes')) {
    final n = Note.fromJson(j);
    if (!noteIds.add(n.id)) continue;
    for (final a in n.attachments) {
      final f = arc.findFile('media/${a.file}');
      if (f == null) continue;
      final dest = File('${s.attachDirPath}/${a.file}');
      if (!await dest.exists()) {
        await dest.writeAsBytes(f.content as List<int>);
      }
    }
    s.notes.add(n);
    r.notes++;
  }

  final taskIds = s.tasks.map((e) => e.id).toSet();
  final newTasks = <TaskItem>[];
  for (final j in list('tasks')) {
    final t = TaskItem.fromJson(j);
    if (!taskIds.add(t.id)) continue;
    s.tasks.add(t);
    newTasks.add(t);
    r.tasks++;
  }

  final ideaIds = s.ideas.map((e) => e.id).toSet();
  for (final j in list('ideas')) {
    final i = Idea.fromJson(j);
    if (ideaIds.add(i.id)) {
      s.ideas.add(i);
      r.ideas++;
    }
  }

  await s.saveAll();
  for (final t in newTasks) {
    try {
      await Notifier.sync(t);
    } catch (_) {}
  }
  return r;
}

void showBackupSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF111111),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _BackupSheet(parent: context),
  );
}

class _BackupSheet extends StatefulWidget {
  final BuildContext parent;
  const _BackupSheet({required this.parent});

  @override
  State<_BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends State<_BackupSheet> {
  bool _busy = false;

  void _msg(String text) {
    ScaffoldMessenger.of(widget.parent)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final bytes = await buildBackup();
      final name =
          'JoesNotes-backup-${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.zip';
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: t('export_data'),
        fileName: name,
        bytes: bytes,
      );
      if (mounted) Navigator.pop(context);
      if (saved != null) _msg(t('backup_saved'));
    } catch (_) {
      if (mounted) Navigator.pop(context);
      _msg(t('backup_failed'));
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(withData: true);
      if (picked == null || picked.files.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final f = picked.files.single;
      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null) throw const FormatException('empty');
      final r = await restoreBackup(bytes);
      if (mounted) Navigator.pop(context);
      if (r.nothing) {
        _msg(t('restore_nothing'));
      } else {
        _msg('${t('restore_done')}: ${r.notes} ${t('note_word')}، '
            '${r.tasks} ${t('tasks_word')}، ${r.ideas} ${t('ideas_word')}');
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
      _msg(t('restore_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap) {
      return ListTile(
        enabled: !_busy,
        leading: Icon(icon, color: kOrange),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(sub,
            style: const TextStyle(fontSize: 12.5, color: Colors.white54)),
        onTap: onTap,
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(t('backup'),
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
            ),
            if (_busy)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator(color: kOrange)),
              )
            else ...[
              tile(Icons.upload_file_rounded, t('export_data'),
                  t('export_hint'), _export),
              tile(Icons.download_rounded, t('import_data'), t('import_hint'),
                  _import),
            ],
          ],
        ),
      ),
    );
  }
}
