import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

String fmtDate(DateTime d) =>
    DateFormat('d MMM y • h:mm a', Store.i.lang.value).format(d);

/// Search matches the title, the text and the keywords.
bool noteMatches(Note n, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return n.title.toLowerCase().contains(q) ||
      n.plain.toLowerCase().contains(q) ||
      n.keywords.any((k) => k.toLowerCase().contains(q));
}

Future<void> confirmDeleteNote(BuildContext context, Note n) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('delete_note_q')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t('delete'),
              style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  if (ok == true) await Store.i.deleteNote(n.id);
}

class NotesGrid extends StatelessWidget {
  final List<Note> notes;
  final double bottomPadding;
  final void Function(Note) onOpen;
  const NotesGrid({
    super.key,
    required this.notes,
    required this.onOpen,
    this.bottomPadding = 170,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: notes.length,
      itemBuilder: (_, i) => NoteCard(
        note: notes[i],
        onTap: () => onOpen(notes[i]),
        onLongPress: () => confirmDeleteNote(context, notes[i]),
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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasTitle) ...[
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.3),
              ),
              const SizedBox(height: 4),
            ],
            Expanded(
              child: Text(
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
                    style: const TextStyle(fontSize: 11, color: kOrange),
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
