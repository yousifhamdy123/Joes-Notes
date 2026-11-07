import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'notes_page.dart' show fmtDate;

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final QuillController _c;
  late final DateTime _created;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _created = widget.note?.created ?? DateTime.now();
    Document doc;
    try {
      doc = widget.note == null
          ? Document()
          : Document.fromJson(jsonDecode(widget.note!.delta));
    } catch (_) {
      doc = Document();
    }
    _c = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  Future<void> _save() async {
    if (_saved) return;
    _saved = true;
    final plain = _c.document.toPlainText().trim();
    final existing = widget.note;
    if (plain.isEmpty) {
      if (existing != null) await Store.i.deleteNote(existing.id);
      return;
    }
    await Store.i.upsertNote(Note(
      id: existing?.id ?? Store.newId(),
      delta: jsonEncode(_c.document.toDelta().toJson()),
      plain: plain,
      created: _created,
      updated: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${t('created')}: ${fmtDate(_created)}',
            style: const TextStyle(fontSize: 14, color: Colors.white60),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.check_rounded, color: kOrange, size: 28),
              tooltip: t('save'),
              onPressed: () async {
                await _save();
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: const Color(0xFF101010),
              child: QuillSimpleToolbar(
                controller: _c,
                config: QuillSimpleToolbarConfig(
                  multiRowsDisplay: false,
                  showFontFamily: true,
                  showFontSize: true,
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showStrikeThrough: true,
                  showColorButton: true,
                  showBackgroundColorButton: true, // highlight
                  showListBullets: true,
                  showListNumbers: true,
                  showListCheck: true,
                  showAlignmentButtons: true,
                  showDirection: true,
                  showClearFormat: true,
                  showUndo: true,
                  showRedo: true,
                  showHeaderStyle: false,
                  showCodeBlock: false,
                  showInlineCode: false,
                  showQuote: false,
                  showIndent: false,
                  showLink: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                  buttonOptions: QuillSimpleToolbarButtonOptions(
                    fontFamily: QuillToolbarFontFamilyButtonOptions(
                      items: const {
                        'Sans': 'sans-serif',
                        'Serif': 'serif',
                        'Mono': 'monospace',
                        'Handwritten': 'cursive',
                        'Casual': 'casual',
                        'Condensed': 'sans-serif-condensed',
                      },
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: QuillEditor.basic(
                controller: _c,
                config: QuillEditorConfig(
                  placeholder: t('start_writing'),
                  padding: const EdgeInsets.all(16),
                  autoFocus: widget.note == null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
