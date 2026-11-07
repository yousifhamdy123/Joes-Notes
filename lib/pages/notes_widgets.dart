import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n.dart';
import '../lock.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'note_editor.dart';
import 'trash_page.dart';

String fmtDate(DateTime d) =>
    DateFormat('d MMM y • h:mm a', Store.i.lang.value).format(d);

/// Search matches the title, the text and the keywords.
/// Locked notes only match on title and keywords (their text stays private).
bool noteMatches(Note n, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return n.title.toLowerCase().contains(q) ||
      (!n.locked && n.plain.toLowerCase().contains(q)) ||
      n.keywords.any((k) => k.toLowerCase().contains(q));
}

void snack(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}

/// Opens a note, asking for fingerprint / PIN first when it is locked.
Future<void> openNote(BuildContext context, Note? n,
    {String? notebookId}) async {
  if (n != null && n.locked) {
    final ok = await authenticate();
    if (!ok) {
      if (context.mounted) snack(context, t('auth_failed'));
      return;
    }
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NoteEditorPage(note: n, notebookId: notebookId),
    ),
  );
}

Future<void> trashWithUndo(BuildContext context, Note n) async {
  await Store.i.trashNote(n);
  if (context.mounted) {
    snack(
      context,
      t('moved_trash'),
      action: SnackBarAction(
        label: t('undo'),
        textColor: kOrange,
        onPressed: () => Store.i.restoreNote(n),
      ),
    );
  }
}

/// Long-press menu on a note card.
Future<void> showNoteActions(BuildContext context, Note n) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF111111),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(n.pinned ? t('unpin') : t('pin')),
            onTap: () => Navigator.pop(ctx, 'pin'),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(t('archive_note')),
            onTap: () => Navigator.pop(ctx, 'archive'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: Text(t('move_to_trash'),
                style: const TextStyle(color: Colors.redAccent)),
            onTap: () => Navigator.pop(ctx, 'trash'),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  if (choice == 'pin') {
    n.pinned = !n.pinned;
    await Store.i.upsertNote(n);
  } else if (choice == 'archive') {
    await Store.i.setArchived(n, true);
    if (context.mounted) {
      snack(
        context,
        t('moved_archive'),
        action: SnackBarAction(
          label: t('undo'),
          textColor: kOrange,
          onPressed: () => Store.i.setArchived(n, false),
        ),
      );
    }
  } else if (choice == 'trash') {
    if (context.mounted) await trashWithUndo(context, n);
  }
}

/// Sort / view / archive / trash menu shown next to the search field.
class NotesMenuButton extends StatelessWidget {
  const NotesMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    PopupMenuItem<String> sortItem(String mode, String label) =>
        PopupMenuItem(
          value: 'sort:$mode',
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: s.sortMode == mode
                    ? Icon(Icons.check_rounded, size: 18, color: kOrange)
                    : null,
              ),
              Text(label),
            ],
          ),
        );

    final menu = PopupMenuButton<String>(
      tooltip: t('sort'),
      icon: Icon(Icons.more_vert_rounded, color: kOrange),
      onSelected: (v) {
        if (v.startsWith('sort:')) {
          s.setSortMode(v.substring(5));
        } else if (v == 'view') {
          s.setListView(!s.listView);
        } else if (v == 'archive' || v == 'trash') {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NoteListPage(archive: v == 'archive')));
        }
      },
      itemBuilder: (_) => [
        sortItem('newest', t('sort_newest')),
        sortItem('oldest', t('sort_oldest')),
        sortItem('updated', t('sort_updated')),
        sortItem('az', t('sort_az')),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'view',
          child: Row(children: [
            Icon(s.listView ? Icons.grid_view_rounded : Icons.view_agenda_outlined,
                size: 20),
            const SizedBox(width: 10),
            Text(s.listView ? t('view_grid') : t('view_list')),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'archive',
          child: Row(children: [
            const Icon(Icons.archive_outlined, size: 20),
            const SizedBox(width: 10),
            Text(t('archive')),
          ]),
        ),
        PopupMenuItem(
          value: 'trash',
          child: Row(children: [
            const Icon(Icons.delete_outline, size: 20),
            const SizedBox(width: 10),
            Text(t('trash')),
          ]),
        ),
      ],
    );

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
      ),
      child: menu,
    );
  }
}

class NotesGrid extends StatelessWidget {
  final List<Note> notes;
  final double bottomPadding;
  final void Function(Note) onOpen;
  final void Function(Note)? onLongPress;
  const NotesGrid({
    super.key,
    required this.notes,
    required this.onOpen,
    this.onLongPress,
    this.bottomPadding = 170,
  });

  @override
  Widget build(BuildContext context) {
    final items = Store.i.sorted(notes);
    void longPress(Note n) => (onLongPress ?? (x) => showNoteActions(context, x))(n);

    if (Store.i.listView) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => SizedBox(
          height: 112,
          child: NoteCard(
            note: items[i],
            onTap: () => onOpen(items[i]),
            onLongPress: () => longPress(items[i]),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => NoteCard(
        note: items[i],
        onTap: () => onOpen(items[i]),
        onLongPress: () => longPress(items[i]),
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = note.title.isNotEmpty;
    final tinted = note.color != 0;
    final bg = tinted ? Color(note.color) : kCard;
    final border = tinted
        ? Color.lerp(Color(note.color), Colors.white, 0.22)!
        : kCardBorder;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasTitle || note.pinned) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      hasTitle ? note.title : '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          height: 1.3),
                    ),
                  ),
                  if (note.pinned)
                    Icon(Icons.push_pin, size: 16, color: kOrange),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Expanded(
              child: note.locked
                  ? Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 18, color: Colors.white54),
                        const SizedBox(width: 6),
                        Text(t('locked_note'),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white54)),
                      ],
                    )
                  : Text(
                      note.plain,
                      maxLines: hasTitle ? 3 : 6,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: hasTitle ? Colors.white70 : Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    fmtDate(note.created),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: kOrange),
                  ),
                ),
                if (note.imageCount > 0) ...[
                  const Icon(Icons.image_outlined,
                      size: 14, color: Colors.white54),
                  const SizedBox(width: 2),
                ],
                if (note.audioCount > 0)
                  const Icon(Icons.mic_none_rounded,
                      size: 14, color: Colors.white54),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
