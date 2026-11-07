import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'notebook_page.dart';

/// Asks for a notebook name. Returns null if cancelled or empty.
Future<String?> askNotebookName(BuildContext context,
    {String initial = ''}) async {
  final ctl = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(initial.isEmpty ? t('new_notebook') : t('rename')),
      content: TextField(
        controller: ctl,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(ctx, v),
        decoration: InputDecoration(hintText: t('notebook_name')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctl.text),
          child: Text(t('save'), style: const TextStyle(color: kOrange)),
        ),
      ],
    ),
  );
  ctl.dispose();
  final name = result?.trim() ?? '';
  return name.isEmpty ? null : name;
}

Future<bool> confirmDeleteNotebook(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('delete_notebook_q')),
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
  return ok == true;
}

class NotebooksPage extends StatelessWidget {
  const NotebooksPage({super.key});

  Future<void> _create(BuildContext context) async {
    final name = await askNotebookName(context);
    if (name == null) return;
    await Store.i.upsertNotebook(
        Notebook(id: Store.newId(), name: name, created: DateTime.now()));
  }

  Future<void> _options(BuildContext context, Notebook b) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(t('rename')),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text(t('delete_notebook'),
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'rename') {
      final name = await askNotebookName(context, initial: b.name);
      if (name != null) {
        await Store.i.upsertNotebook(
            Notebook(id: b.id, name: name, created: b.created));
      }
    } else if (choice == 'delete') {
      if (await confirmDeleteNotebook(context)) {
        await Store.i.deleteNotebook(b.id);
      }
    }
  }

  void _openBook(BuildContext context, Notebook? b) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => NotebookPage(notebookId: b?.id)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Store.i.lang]),
      builder: (context, _) {
        final books = Store.i.notebooks;
        return Scaffold(
          appBar: AppBar(title: Text(t('notebooks'))),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _create(context),
            backgroundColor: kOrange,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.add_rounded, size: 32),
          ),
          body: GridView.count(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _BookCard(
                name: t('unassigned'),
                count: Store.i.countIn(null),
                icon: Icons.inbox_outlined,
                onTap: () => _openBook(context, null),
              ),
              for (final b in books)
                _BookCard(
                  name: b.name,
                  count: Store.i.countIn(b.id),
                  icon: Icons.menu_book_rounded,
                  onTap: () => _openBook(context, b),
                  onLongPress: () => _options(context, b),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  final String name;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _BookCard({
    required this.name,
    required this.count,
    required this.icon,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, color: kOrange, size: 28),
            const Spacer(),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              '$count ${t('note_word')}',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
