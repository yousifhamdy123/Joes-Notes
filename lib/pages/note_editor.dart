import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'attachments.dart';
import 'notebooks_page.dart' show askNotebookName;
import 'notes_widgets.dart' show fmtDate;

const _highlightColors = [
  '#FFF59D', '#FFCC80', '#F8BBD0', '#C5E1A5', '#81D4FA', '#CE93D8',
];

Color? _parseHex(String s) {
  var h = s.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// Soft, feathered highlight: translucent colour with blurred edges instead
/// of Quill's default hard rectangle.
TextStyle _customStyle(Attribute a) {
  if (a.key == 'background' && a.value is String) {
    final c = _parseHex(a.value as String);
    if (c != null) {
      return TextStyle(
        background: Paint()
          ..color = c.withValues(alpha: 0.42)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }
  }
  return const TextStyle();
}

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  final String? notebookId; // preset when adding from inside a notebook
  const NoteEditorPage({super.key, this.note, this.notebookId});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final QuillController _c;
  late final TextEditingController _title;
  late final DateTime _created;
  late final List<String> _keywords;
  late final List<Attachment> _atts;
  final List<Attachment> _removed = [];
  late final Set<String> _books;
  bool _tools = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _created = n?.created ?? DateTime.now();
    _title = TextEditingController(text: n?.title ?? '');
    _keywords = [...?n?.keywords];
    _atts = [...?n?.attachments];
    _books = {
      ...?n?.notebooks,
      if (n == null && widget.notebookId != null) widget.notebookId!,
    };
    Document doc;
    try {
      doc = n == null ? Document() : Document.fromJson(jsonDecode(n.delta));
    } catch (_) {
      doc = Document();
    }
    _c = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saved) return;
    _saved = true;
    final plain = _c.document.toPlainText().trim();
    final title = _title.text.trim();
    final existing = widget.note;
    await Store.i.deleteFiles(_removed);
    final empty =
        plain.isEmpty && title.isEmpty && _atts.isEmpty && _keywords.isEmpty;
    if (empty) {
      if (existing != null) await Store.i.deleteNote(existing.id);
      return;
    }
    await Store.i.upsertNote(Note(
      id: existing?.id ?? Store.newId(),
      title: title,
      delta: jsonEncode(_c.document.toDelta().toJson()),
      plain: plain,
      keywords: _keywords,
      notebooks: _books.toList(),
      attachments: _atts,
      created: _created,
      updated: DateTime.now(),
    ));
  }

  // ---- keywords ----
  Future<void> _addKeyword() async {
    final ctl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('add_keyword')),
        content: TextField(
          controller: ctl,
          autofocus: true,
          onSubmitted: (s) => Navigator.pop(ctx, s),
          decoration: InputDecoration(hintText: t('keyword_hint')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: Text(t('add'), style: const TextStyle(color: kOrange)),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (v == null) return;
    final parts = v
        .split(RegExp(r'[,،\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    setState(() {
      for (final p in parts) {
        if (!_keywords.contains(p)) _keywords.add(p);
      }
    });
  }

  // ---- notebooks (a note can belong to several) ----
  Future<void> _pickNotebook() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(t('choose_notebook'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                for (final b in Store.i.notebooks)
                  CheckboxListTile(
                    value: _books.contains(b.id),
                    activeColor: kOrange,
                    checkColor: Colors.black,
                    secondary: const Icon(Icons.menu_book_rounded),
                    title: Text(b.name),
                    onChanged: (v) {
                      setSheet(() {});
                      setState(() {
                        if (v == true) {
                          _books.add(b.id);
                        } else {
                          _books.remove(b.id);
                        }
                      });
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.add_rounded, color: kOrange),
                  title: Text(t('new_notebook'),
                      style: const TextStyle(color: kOrange)),
                  onTap: () async {
                    final name = await askNotebookName(ctx);
                    if (name == null) return;
                    final nb = Notebook(
                        id: Store.newId(), name: name, created: DateTime.now());
                    await Store.i.upsertNotebook(nb);
                    setSheet(() {});
                    setState(() => _books.add(nb.id));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- highlight ----
  Future<void> _pickHighlight() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('highlight'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final hex in _highlightColors)
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, hex),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _parseHex(hex)!.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, 'none'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.format_color_reset_outlined,
                          size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (r == null) return;
    _c.formatSelection(r == 'none'
        ? Attribute.clone(Attribute.background, null)
        : Attribute.fromKeyValue('background', r));
  }

  // ---- attachments ----
  Future<void> _addImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t('camera')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t('gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    try {
      final picker = ImagePicker();
      final List<XFile> files;
      if (src == ImageSource.gallery) {
        files = await picker.pickMultiImage(imageQuality: 85, maxWidth: 2048);
      } else {
        final x = await picker.pickImage(
            source: src, imageQuality: 85, maxWidth: 2048);
        files = x == null ? [] : [x];
      }
      for (final x in files) {
        final dot = x.path.lastIndexOf('.');
        var ext = dot >= 0 ? x.path.substring(dot + 1).toLowerCase() : 'jpg';
        if (ext.length > 4) ext = 'jpg';
        final dest = Store.i.newAttachPath(ext);
        await File(x.path).copy(dest);
        _atts.add(Attachment(
          id: Store.newId(),
          type: 'image',
          file: dest.split('/').last,
        ));
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _record() async {
    FocusScope.of(context).unfocus();
    final a = await showModalBottomSheet<Attachment>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF111111),
      builder: (_) => const RecordSheet(),
    );
    if (a != null) setState(() => _atts.add(a));
  }

  void _removeAttachment(Attachment a) {
    setState(() => _atts.removeWhere((e) => e.id == a.id));
    _removed.add(a);
  }

  // ---- UI ----
  Widget _metaRow() {
    final books = [
      for (final id in _books)
        if (Store.i.notebookById(id) != null) Store.i.notebookById(id)!,
    ];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (books.isEmpty)
            ActionChip(
              avatar: const Icon(Icons.menu_book_rounded,
                  size: 16, color: kOrange),
              label: Text(t('unassigned')),
              onPressed: _pickNotebook,
            )
          else
            for (final b in books) ...[
              ActionChip(
                avatar: const Icon(Icons.menu_book_rounded,
                    size: 16, color: kOrange),
                label: Text(b.name),
                onPressed: _pickNotebook,
              ),
              const SizedBox(width: 8),
            ],
          const SizedBox(width: 8),
          for (final k in _keywords) ...[
            InputChip(
              label: Text('# $k'),
              onDeleted: () => setState(() => _keywords.remove(k)),
              deleteIconColor: Colors.white54,
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: Text(t('add_keyword')),
            onPressed: _addKeyword,
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Container(
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
          showBackgroundColorButton: false, // replaced by our soft highlight
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
          customButtons: [
            QuillToolbarCustomButtonOptions(
              icon: const Icon(Icons.brush_rounded, size: 20),
              tooltip: t('highlight'),
              onPressed: _pickHighlight,
            ),
          ],
          buttonOptions: QuillSimpleToolbarButtonOptions(
            fontFamily: QuillToolbarFontFamilyButtonOptions(
              items: const {
                ...kArabicFonts,
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
    );
  }

  Widget _bottomBar() {
    Widget btn(IconData icon, String tip, VoidCallback onTap,
        {bool active = false}) {
      return IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon, color: active ? kOrange : Colors.white70),
        style: IconButton.styleFrom(
          backgroundColor:
              active ? kOrange.withValues(alpha: 0.2) : Colors.transparent,
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101010),
        border: Border(top: BorderSide(color: Color(0xFF222222))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          btn(Icons.text_fields_rounded, t('text_tools'),
              () => setState(() => _tools = !_tools),
              active: _tools),
          btn(Icons.image_outlined, t('add_image'), _addImage),
          btn(Icons.mic_none_rounded, t('record_voice'), _record),
        ],
      ),
    );
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
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: t('title_hint'),
                    hintStyle: const TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                  ),
                ),
              ),
              _metaRow(),
              Expanded(
                child: QuillEditor.basic(
                  controller: _c,
                  config: QuillEditorConfig(
                    placeholder: t('start_writing'),
                    padding: const EdgeInsets.all(16),
                    autoFocus: widget.note == null,
                    customStyleBuilder: _customStyle,
                  ),
                ),
              ),
              if (_atts.isNotEmpty)
                AttachmentStrip(items: _atts, onRemove: _removeAttachment),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.bottomCenter,
                child: _tools
                    ? _toolbar()
                    : const SizedBox(width: double.infinity),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }
}
