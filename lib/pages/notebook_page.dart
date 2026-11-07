import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'note_editor.dart';
import 'notebooks_page.dart';
import 'notes_widgets.dart';

/// Notes of one notebook. [notebookId] == null shows notes without a notebook.
class NotebookPage extends StatefulWidget {
  final String? notebookId;
  const NotebookPage({super.key, required this.notebookId});

  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage> {
  String _q = '';

  void _open([Note? n]) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              NoteEditorPage(note: n, notebookId: widget.notebookId),
        ),
      );

  Future<void> _menu(String v, Notebook b) async {
    if (v == 'rename') {
      final name = await askNotebookName(context, initial: b.name);
      if (name != null) {
        await Store.i
            .upsertNotebook(Notebook(id: b.id, name: name, created: b.created));
      }
    } else if (v == 'delete') {
      if (await confirmDeleteNotebook(context)) {
        await Store.i.deleteNotebook(b.id);
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Store.i.lang]),
      builder: (context, _) {
        final book = Store.i.notebookById(widget.notebookId);
        final notes = Store.i.notes
            .where((n) => widget.notebookId == null
                ? n.notebooks.isEmpty
                : n.notebooks.contains(widget.notebookId))
            .where((n) => noteMatches(n, _q))
            .toList();
        final empty = Store.i.countIn(widget.notebookId) == 0;

        return Scaffold(
          appBar: AppBar(
            title: Text(book?.name ?? t('unassigned')),
            actions: [
              if (book != null)
                PopupMenuButton<String>(
                  onSelected: (v) => _menu(v, book),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(t('rename'))),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(t('delete_notebook'),
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _open(),
            backgroundColor: kOrange,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.add_rounded, size: 32),
          ),
          body: Column(
            children: [
              AppSearchField(onChanged: (v) => setState(() => _q = v)),
              Expanded(
                child: notes.isEmpty
                    ? EmptyState(empty ? t('no_notes') : t('no_results'))
                    : NotesGrid(
                        notes: notes, onOpen: _open, bottomPadding: 100),
              ),
            ],
          ),
        );
      },
    );
  }
}
