import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'notes_widgets.dart';

/// Archive (archive == true) or trash (archive == false).
class NoteListPage extends StatelessWidget {
  final bool archive;
  const NoteListPage({super.key, required this.archive});

  Future<bool> _confirm(BuildContext context, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('delete_forever'),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _trashMenu(BuildContext context, Note n) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore_from_trash_rounded),
              title: Text(t('restore')),
              onTap: () => Navigator.pop(ctx, 'restore'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined,
                  color: Colors.redAccent),
              title: Text(t('delete_forever'),
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'restore') {
      await Store.i.restoreNote(n);
    } else if (choice == 'delete' && context.mounted) {
      if (await _confirm(context, t('delete_forever_q'))) {
        await Store.i.deleteNote(n.id);
      }
    }
  }

  Future<void> _archiveMenu(BuildContext context, Note n) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.unarchive_outlined),
              title: Text(t('unarchive')),
              onTap: () => Navigator.pop(ctx, 'unarchive'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text(t('move_to_trash'),
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'trash'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'unarchive') {
      await Store.i.setArchived(n, false);
    } else if (choice == 'trash' && context.mounted) {
      await trashWithUndo(context, n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Store.i.lang]),
      builder: (context, _) {
        final notes =
            archive ? Store.i.archivedNotes : Store.i.trashedNotes;
        return Scaffold(
          appBar: AppBar(
            title: Text(archive ? t('archive') : t('trash')),
            actions: [
              if (!archive && notes.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    if (await _confirm(context, t('empty_trash_q'))) {
                      await Store.i.emptyTrash();
                    }
                  },
                  child: Text(t('empty_trash'),
                      style: const TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
          body: Column(
            children: [
              if (!archive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(t('trash_hint'),
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.white54)),
                ),
              Expanded(
                child: notes.isEmpty
                    ? EmptyState(
                        archive ? t('archive_empty') : t('trash_empty'))
                    : NotesGrid(
                        notes: notes,
                        bottomPadding: 40,
                        onOpen: (n) => archive
                            ? openNote(context, n)
                            : _trashMenu(context, n),
                        onLongPress: (n) => archive
                            ? _archiveMenu(context, n)
                            : _trashMenu(context, n),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
