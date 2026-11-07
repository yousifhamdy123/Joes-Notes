import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../l10n.dart';
import '../lock.dart';
import '../models.dart';
import '../store.dart';
import '../templates.dart';
import '../widgets.dart';
import 'attachments.dart';
import 'notebooks_page.dart' show askNotebookName;
import 'notes_widgets.dart' show fmtDate, snack;

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

int _countWords(String s) =>
    s.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).length;

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  final String? notebookId; // preset when adding from inside a notebook
  final String? initialText; // text shared from another app
  const NoteEditorPage({
    super.key,
    this.note,
    this.notebookId,
    this.initialText,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage>
    with WidgetsBindingObserver {
  late final QuillController _c;
  late final TextEditingController _title;
  late final DateTime _created;
  late final String _id;
  late final List<String> _keywords;
  late final List<Attachment> _atts;
  late final Set<String> _books;
  final List<Attachment> _removed = [];
  final ValueNotifier<int> _words = ValueNotifier(0);
  StreamSubscription<dynamic>? _docSub;
  Timer? _debounce;

  bool _pinned = false;
  bool _archived = false;
  bool _locked = false;
  int _color = 0;
  bool _tools = false;
  bool _skipFinal = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _dictating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final n = widget.note;
    _id = n?.id ?? Store.newId();
    _created = n?.created ?? DateTime.now();
    _title = TextEditingController(text: n?.title ?? '');
    _keywords = [...?n?.keywords];
    _atts = [...?n?.attachments];
    _books = {
      ...?n?.notebooks,
      if (n == null && widget.notebookId != null) widget.notebookId!,
    };
    _pinned = n?.pinned ?? false;
    _archived = n?.archived ?? false;
    _locked = n?.locked ?? false;
    _color = n?.color ?? 0;

    Document doc;
    try {
      doc = n == null ? Document() : Document.fromJson(jsonDecode(n.delta));
    } catch (_) {
      doc = Document();
    }
    if (n == null && (widget.initialText ?? '').isNotEmpty) {
      doc.insert(0, widget.initialText!);
    }
    _c = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _bindDoc();
    _title.addListener(_scheduleSave);
  }

  /// (Re)subscribes to the current document: word count + autosave.
  void _bindDoc() {
    _docSub?.cancel();
    _words.value = _countWords(_c.document.toPlainText());
    _docSub = _c.document.changes.listen((_) {
      _words.value = _countWords(_c.document.toPlainText());
      _scheduleSave();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _docSub?.cancel();
    _speech.cancel();
    _c.dispose();
    _title.dispose();
    _words.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _persist();
  }

  // ---- saving ----
  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _persist);
  }

  Future<void> _persist({bool finalSave = false}) async {
    if (_skipFinal) return;
    _debounce?.cancel();
    final plain = _c.document.toPlainText().trim();
    final title = _title.text.trim();
    final empty =
        plain.isEmpty && title.isEmpty && _atts.isEmpty && _keywords.isEmpty;
    if (empty) {
      if (finalSave && Store.i.noteById(_id) != null) {
        await Store.i.deleteNote(_id);
      }
      return;
    }
    final old = Store.i.noteById(_id);
    await Store.i.upsertNote(Note(
      id: _id,
      title: title,
      delta: jsonEncode(_c.document.toDelta().toJson()),
      plain: plain,
      keywords: [..._keywords],
      notebooks: _books.toList(),
      attachments: [..._atts],
      pinned: _pinned,
      color: _color,
      archived: _archived,
      locked: _locked,
      deletedAt: old?.deletedAt,
      created: _created,
      updated: DateTime.now(),
    ));
    if (finalSave) await Store.i.deleteFiles(_removed);
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
            child: Text(t('add'), style: TextStyle(color: kOrange)),
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
    _scheduleSave();
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
                      _scheduleSave();
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.add_rounded, color: kOrange),
                  title: Text(t('new_notebook'),
                      style: TextStyle(color: kOrange)),
                  onTap: () async {
                    final name = await askNotebookName(ctx);
                    if (name == null) return;
                    final nb = Notebook(
                        id: Store.newId(), name: name, created: DateTime.now());
                    await Store.i.upsertNotebook(nb);
                    setSheet(() {});
                    setState(() => _books.add(nb.id));
                    _scheduleSave();
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

  // ---- inserting text (dictation, templates, date) ----
  void _insertText(String text) {
    if (text.isEmpty) return;
    final len = _c.document.length;
    var off = _c.selection.baseOffset;
    if (off < 0 || off > len - 1) off = len - 1;
    _c.replaceText(
      off,
      0,
      text,
      TextSelection.collapsed(offset: off + text.length),
    );
  }

  void _insertDate() => _insertText('${fmtDate(DateTime.now())} ');

  Future<void> _toggleDictation() async {
    if (_dictating) {
      await _speech.stop();
      if (mounted) setState(() => _dictating = false);
      return;
    }
    try {
      if (!_speechReady) {
        _speechReady = await _speech.initialize(
          onStatus: (s) {
            if ((s == 'done' || s == 'notListening') && mounted) {
              setState(() => _dictating = false);
            }
          },
          onError: (_) {
            if (mounted) setState(() => _dictating = false);
          },
        );
      }
      if (!_speechReady) {
        if (mounted) snack(context, t('dictate_unavailable'));
        return;
      }
      String? localeId;
      final want = Store.i.lang.value == 'ar' ? 'ar' : 'en';
      final locales = await _speech.locales();
      final match = locales
          .where((l) => l.localeId.toLowerCase().startsWith(want))
          .toList();
      if (match.isNotEmpty) {
        final eg = match.where((l) => l.localeId.toLowerCase().contains('eg'));
        localeId = (eg.isNotEmpty ? eg.first : match.first).localeId;
      }
      if (mounted) setState(() => _dictating = true);
      await _speech.listen(
        onResult: (r) {
          if (r.finalResult) _insertText('${r.recognizedWords} ');
        },
        localeId: localeId,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _dictating = false);
        snack(context, t('dictate_unavailable'));
      }
    }
  }

  Future<void> _pickTemplate() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(t('templates'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
            for (final tpl in kTemplates)
              ListTile(
                leading: Icon(tpl.icon, color: kOrange),
                title: Text(t('tpl_${tpl.id}')),
                onTap: () => Navigator.pop(ctx, tpl.id),
              ),
          ],
        ),
      ),
    );
    if (id == null) return;
    final isEmpty = _c.document.toPlainText().trim().isEmpty;
    if (isEmpty) {
      _c.document = Document.fromJson(templateDelta(id));
      _bindDoc();
      if (_title.text.trim().isEmpty) _title.text = templateTitle(id);
      setState(() {});
    } else {
      _insertText('${templatePlain(id)}\n');
    }
    _scheduleSave();
  }

  // ---- note options (pin, color, lock, archive, trash) ----
  Future<void> _pickColor() async {
    final c = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('note_color'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final col in kNoteColors)
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, col),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: col == 0 ? kCard : Color(col),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: col == _color ? kOrange : Colors.white24,
                            width: col == _color ? 3 : 1,
                          ),
                        ),
                        child: col == 0
                            ? const Icon(Icons.format_color_reset_outlined,
                                size: 20, color: Colors.white54)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (c == null) return;
    setState(() => _color = c);
    _scheduleSave();
  }

  Future<void> _toggleLock() async {
    if (_locked) {
      if (!await authenticate()) {
        if (mounted) snack(context, t('auth_failed'));
        return;
      }
      setState(() => _locked = false);
    } else {
      if (!await deviceCanAuth()) {
        if (mounted) snack(context, t('auth_unavailable'));
        return;
      }
      setState(() => _locked = true);
    }
    _scheduleSave();
  }

  Future<void> _moveAway({required bool toTrash}) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    await _persist();
    final n = Store.i.noteById(_id);
    _skipFinal = true;
    if (n != null) {
      if (toTrash) {
        await Store.i.trashNote(n);
      } else {
        await Store.i.setArchived(n, true);
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(toTrash ? t('moved_trash') : t('moved_archive')),
          action: SnackBarAction(
            label: t('undo'),
            textColor: kOrange,
            onPressed: () => toTrash
                ? Store.i.restoreNote(n)
                : Store.i.setArchived(n, false),
          ),
        ));
    }
    nav.pop();
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
      _scheduleSave();
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
    if (a != null) {
      setState(() => _atts.add(a));
      _scheduleSave();
    }
  }

  void _removeAttachment(Attachment a) {
    setState(() => _atts.removeWhere((e) => e.id == a.id));
    _removed.add(a);
    _scheduleSave();
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
              avatar: Icon(Icons.menu_book_rounded, size: 16, color: kOrange),
              label: Text(t('unassigned')),
              onPressed: _pickNotebook,
            )
          else
            for (final b in books) ...[
              ActionChip(
                avatar:
                    Icon(Icons.menu_book_rounded, size: 16, color: kOrange),
                label: Text(b.name),
                onPressed: _pickNotebook,
              ),
              const SizedBox(width: 8),
            ],
          const SizedBox(width: 8),
          for (final k in _keywords) ...[
            InputChip(
              label: Text('# $k'),
              onDeleted: () {
                setState(() => _keywords.remove(k));
                _scheduleSave();
              },
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
        {bool active = false, Color? color}) {
      return IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon, color: color ?? (active ? kOrange : Colors.white70)),
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  btn(Icons.text_fields_rounded, t('text_tools'),
                      () => setState(() => _tools = !_tools),
                      active: _tools),
                  btn(Icons.image_outlined, t('add_image'), _addImage),
                  btn(Icons.mic_none_rounded, t('record_voice'), _record),
                  btn(
                    _dictating
                        ? Icons.stop_circle_outlined
                        : Icons.keyboard_voice_outlined,
                    _dictating ? t('listening') : t('dictate'),
                    _toggleDictation,
                    active: _dictating,
                    color: _dictating ? Colors.redAccent : null,
                  ),
                  btn(Icons.dashboard_customize_outlined, t('templates'),
                      _pickTemplate),
                  btn(Icons.event_outlined, t('insert_date'), _insertDate),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _words,
            builder: (_, n, __) => Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 6),
              child: Text('$n ${t('words_word')}',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white54)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_skipFinal) _persist(finalSave: true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${t('created')}: ${fmtDate(_created)}',
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                switch (v) {
                  case 'pin':
                    setState(() => _pinned = !_pinned);
                    _scheduleSave();
                    break;
                  case 'color':
                    _pickColor();
                    break;
                  case 'lock':
                    _toggleLock();
                    break;
                  case 'archive':
                    _moveAway(toTrash: false);
                    break;
                  case 'trash':
                    _moveAway(toTrash: true);
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Row(children: [
                    Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(_pinned ? t('unpin') : t('pin')),
                  ]),
                ),
                PopupMenuItem(
                  value: 'color',
                  child: Row(children: [
                    const Icon(Icons.palette_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(t('note_color')),
                  ]),
                ),
                PopupMenuItem(
                  value: 'lock',
                  child: Row(children: [
                    Icon(
                        _locked
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(_locked ? t('unlock') : t('lock')),
                  ]),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: Row(children: [
                    const Icon(Icons.archive_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(t('archive_note')),
                  ]),
                ),
                PopupMenuItem(
                  value: 'trash',
                  child: Row(children: [
                    const Icon(Icons.delete_outline,
                        size: 20, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Text(t('move_to_trash'),
                        style: const TextStyle(color: Colors.redAccent)),
                  ]),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.check_rounded, color: kOrange, size: 28),
              tooltip: t('save'),
              onPressed: () async {
                await _persist(finalSave: true);
                _skipFinal = true;
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
