import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'note_editor.dart';
import 'notebooks_page.dart';
import 'notes_widgets.dart';

export 'notes_widgets.dart' show fmtDate;

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String _q = '';

  void _open([Note? n]) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NoteEditorPage(note: n)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Store.i.lang]),
      builder: (context, _) {
        final notes =
            Store.i.notes.where((n) => noteMatches(n, _q)).toList();

        Widget body;
        if (notes.isEmpty) {
          body = EmptyState(
              Store.i.notes.isEmpty ? t('no_notes') : t('no_results'));
        } else {
          body = NotesGrid(notes: notes, onOpen: _open);
        }

        return Stack(
          children: [
            Column(
              children: [
                AppSearchField(
                  onChanged: (v) => setState(() => _q = v),
                  trailing: IconButton.filled(
                    tooltip: t('notebooks'),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF151515),
                      foregroundColor: kOrange,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotebooksPage()),
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
            AddFab(onPressed: () => _open()),
          ],
        );
      },
    );
  }
}
