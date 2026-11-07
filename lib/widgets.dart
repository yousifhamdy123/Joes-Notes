import 'dart:ui';

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'store.dart';

/// Theme colors follow the user's settings (accent + background).
Color get kOrange => Color(Store.i.accent.value);
Color get kBg => Store.i.bgGray.value ? const Color(0xFF121212) : Colors.black;
Color get kCard =>
    Store.i.bgGray.value ? const Color(0xFF1F1F1F) : const Color(0xFF141414);
Color get kCardBorder =>
    Store.i.bgGray.value ? const Color(0xFF333333) : const Color(0xFF262626);

const kAccentChoices = <int>[
  0xFFFF8A00, 0xFF42A5F5, 0xFF66BB6A, 0xFFEC407A,
  0xFFAB47BC, 0xFFEF5350, 0xFF26C6DA, 0xFFFFCA28,
];

/// Dark tints for note cards (index 0 = default).
const kNoteColors = <int>[
  0, 0xFF4A2323, 0xFF4A3516, 0xFF45401A, 0xFF1F3D2B, 0xFF1D3750, 0xFF3B2852,
  0xFF4A2539,
];

/// Arabic fonts bundled by the build (tool/setup_fonts.py), label -> family.
const kArabicFonts = <String, String>{
  'Cairo': 'Cairo',
  'Tajawal': 'Tajawal',
  'Amiri': 'Amiri',
  'Aref Ruqaa': 'Aref Ruqaa',
  'Reem Kufi': 'Reem Kufi',
};

class AppSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  const AppSearchField({super.key, required this.onChanged, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: t('search'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFF151515),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Orange "+" button, placed above the floating navigation bar.
class AddFab extends StatelessWidget {
  final VoidCallback onPressed;
  const AddFab({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      end: 20,
      bottom: 108,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: kOrange,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, height: 1.6),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Floating frosted navigation bar
// ---------------------------------------------------------------------------

class FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const FloatingNav({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final painters = <CustomPainter Function()>[
      () => _NotesIcon(),
      () => _TasksIcon(),
      () => _IdeasIcon(),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 0, 44, 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (i) {
                  final active = i == index;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 56,
                      height: 48,
                      decoration: BoxDecoration(
                        color: active
                            ? kOrange.withValues(alpha: 0.28)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          opacity: active ? 1 : 0.55,
                          child: CustomPaint(
                            size: const Size(28, 28),
                            painter: painters[i](),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Paint _fill(Color c) => Paint()..color = c;
Paint _line(Color c, double w) => Paint()
  ..color = c
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

/// White square with 3 black lines.
class _NotesIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(w * 0.22)),
      _fill(Colors.white),
    );
    final p = _line(Colors.black, w * 0.075);
    canvas.drawLine(Offset(w * .24, w * .3), Offset(w * .76, w * .3), p);
    canvas.drawLine(Offset(w * .24, w * .5), Offset(w * .76, w * .5), p);
    canvas.drawLine(Offset(w * .24, w * .7), Offset(w * .58, w * .7), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// White page with 3 black squares; the first one has a check mark.
class _TasksIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final page = Rect.fromLTWH(w * .12, 0, w * .76, w);
    canvas.drawRRect(
      RRect.fromRectAndRadius(page, Radius.circular(w * .16)),
      _fill(Colors.white),
    );
    final sq = w * .2;
    final left = w * .5 - sq / 2;
    for (var i = 0; i < 3; i++) {
      final top = w * .14 + i * (sq + w * .1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, sq, sq),
          Radius.circular(w * .05),
        ),
        _fill(Colors.black),
      );
      if (i == 0) {
        final path = Path()
          ..moveTo(left + sq * .22, top + sq * .52)
          ..lineTo(left + sq * .43, top + sq * .72)
          ..lineTo(left + sq * .78, top + sq * .28);
        canvas.drawPath(
          path,
          _line(Colors.white, w * .05)..strokeJoin = StrokeJoin.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// White square whose top edge carries black lines (stacked pages).
class _IdeasIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(w * .22)),
      _fill(Colors.white),
    );
    final p = _line(Colors.black, w * .06);
    canvas.drawLine(Offset(w * .22, w * .2), Offset(w * .78, w * .2), p);
    canvas.drawLine(Offset(w * .3, w * .33), Offset(w * .7, w * .33), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
