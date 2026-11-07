import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

const double _kStickyW = 168;

const _stickyColors = [
  0xFFFFF59D, 0xFFFFCC80, 0xFFF8BBD0, 0xFFC5E1A5,
  0xFF81D4FA, 0xFFCE93D8, 0xFFFFFFFF,
];
const _textColors = [
  0xFF000000, 0xFF0D2B66, 0xFFB71C1C, 0xFF1B5E20, 0xFF4A148C, 0xFFFFFFFF,
];
const _fonts = <String, String>{
  ...kArabicFonts,
  'font_sans': 'sans-serif',
  'font_serif': 'serif',
  'font_mono': 'monospace',
  'font_cursive': 'cursive',
  'font_casual': 'casual',
  'font_cond': 'sans-serif-condensed',
};

class IdeasPage extends StatefulWidget {
  const IdeasPage({super.key});

  @override
  State<IdeasPage> createState() => _IdeasPageState();
}

class _IdeasPageState extends State<IdeasPage> {
  Future<void> _edit(Idea idea, {bool isNew = false}) async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _IdeaSheet(idea: idea, isNew: isNew),
    );
    if (result == 'delete') {
      await Store.i.deleteIdea(idea.id);
    } else if (result is Idea) {
      await Store.i.upsertIdea(result);
    }
  }

  void _add() {
    final n = Store.i.ideas.length;
    _edit(
      Idea(
        id: Store.newId(),
        color: _stickyColors[n % _stickyColors.length],
        x: n.isEven ? 0.04 : 0.96,
        y: 16.0 + (n ~/ 2) * 190,
        angle: ((n % 5) - 2) * 0.03,
      ),
      isNew: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Store.i.lang]),
      builder: (context, _) {
        final ideas = Store.i.ideas;
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, cons) {
                final w = cons.maxWidth;
                final free = math.max(1.0, w - _kStickyW);
                final maxY = ideas.fold<double>(0, (m, e) => math.max(m, e.y));
                final h = math.max(cons.maxHeight, maxY + 360);
                if (ideas.isEmpty) return EmptyState(t('no_ideas'));
                return SingleChildScrollView(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final idea in ideas)
                          Positioned(
                            left: idea.x.clamp(0.0, 1.0) * free,
                            top: idea.y,
                            child: _Sticky(
                              key: ValueKey(idea.id),
                              idea: idea,
                              onTap: () => _edit(idea),
                              onDrag: (d) => setState(() {
                                idea.x = (idea.x + d.dx / free).clamp(0.0, 1.0);
                                idea.y = math.max(0, idea.y + d.dy);
                              }),
                              onDragEnd: Store.i.saveIdeas,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            AddFab(onPressed: _add),
          ],
        );
      },
    );
  }
}

TextStyle _styleOf(Idea i) => TextStyle(
      fontFamily: i.font,
      fontSize: i.size,
      color: Color(i.textColor),
      fontWeight: i.bold ? FontWeight.w800 : FontWeight.w500,
      fontStyle: i.italic ? FontStyle.italic : FontStyle.normal,
      height: 1.3,
    );

class _Sticky extends StatelessWidget {
  final Idea idea;
  final VoidCallback onTap;
  final void Function(Offset delta) onDrag;
  final VoidCallback onDragEnd;
  const _Sticky({
    super.key,
    required this.idea,
    required this.onTap,
    required this.onDrag,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: idea.angle,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (d) => onDrag(d.delta),
        onPanEnd: (_) => onDragEnd(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _kStickyW,
              constraints: const BoxConstraints(minHeight: 150),
              padding: const EdgeInsets.fromLTRB(14, 26, 14, 16),
              decoration: BoxDecoration(
                color: Color(idea.color),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                idea.text.isEmpty ? '…' : idea.text,
                style: _styleOf(idea),
              ),
            ),
            // The "pin" that hangs the sticky note on the board.
            PositionedDirectional(
              top: -7,
              start: _kStickyW / 2 - 8,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdeaSheet extends StatefulWidget {
  final Idea idea;
  final bool isNew;
  const _IdeaSheet({required this.idea, required this.isNew});

  @override
  State<_IdeaSheet> createState() => _IdeaSheetState();
}

class _IdeaSheetState extends State<_IdeaSheet> {
  late Idea _i;
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    final o = widget.idea;
    // Work on a copy so "back" discards edits.
    _i = Idea.fromJson(o.toJson());
    _text = TextEditingController(text: o.text);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(s,
            style: const TextStyle(fontSize: 12.5, color: Colors.white54)),
      );

  Widget _swatches(List<int> colors, int selected, ValueChanged<int> onPick) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == selected ? kOrange : Colors.white24,
                  width: c == selected ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(_i.color),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _text,
                autofocus: widget.isNew,
                minLines: 3,
                maxLines: 6,
                onChanged: (v) => setState(() => _i.text = v),
                style: _styleOf(_i),
                cursorColor: Color(_i.textColor),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: t('idea_text'),
                  hintStyle:
                      _styleOf(_i).copyWith(color: Color(_i.textColor).withValues(alpha: 0.4)),
                ),
              ),
            ),
            _label(t('bg_color')),
            _swatches(_stickyColors, _i.color, (c) => setState(() => _i.color = c)),
            _label(t('font')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _fonts.entries)
                  ChoiceChip(
                    label: Text(t(e.key), style: TextStyle(fontFamily: e.value)),
                    selected: _i.font == e.value,
                    selectedColor: kOrange.withValues(alpha: 0.35),
                    onSelected: (_) => setState(() => _i.font = e.value),
                  ),
              ],
            ),
            _label('${t('size')}: ${_i.size.round()}'),
            Slider(
              value: _i.size,
              min: 12,
              max: 36,
              activeColor: kOrange,
              onChanged: (v) => setState(() => _i.size = v),
            ),
            _label(t('text_color')),
            _swatches(_textColors, _i.textColor, (c) => setState(() => _i.textColor = c)),
            const SizedBox(height: 12),
            Row(
              children: [
                FilterChip(
                  label: Text(t('bold')),
                  selected: _i.bold,
                  selectedColor: kOrange.withValues(alpha: 0.35),
                  onSelected: (v) => setState(() => _i.bold = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(t('italic')),
                  selected: _i.italic,
                  selectedColor: kOrange.withValues(alpha: 0.35),
                  onSelected: (v) => setState(() => _i.italic = v),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (!widget.isNew)
                  IconButton(
                    tooltip: t('delete'),
                    onPressed: () => Navigator.pop(context, 'delete'),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      _i.text = _text.text;
                      Navigator.pop(context, _i);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: kOrange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(t('save'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
