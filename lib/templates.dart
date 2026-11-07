import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'store.dart';

class _Row {
  final String text;
  final String kind; // h | p | todo | bullet
  const _Row(this.text, [this.kind = 'p']);
}

class NoteTemplate {
  final String id;
  final IconData icon;
  const NoteTemplate(this.id, this.icon);
}

const kTemplates = <NoteTemplate>[
  NoteTemplate('journal', Icons.wb_sunny_outlined),
  NoteTemplate('meeting', Icons.groups_outlined),
  NoteTemplate('shopping', Icons.shopping_cart_outlined),
  NoteTemplate('plan', Icons.checklist_rounded),
];

bool get _ar => Store.i.lang.value == 'ar';

String templateTitle(String id) {
  final date = DateFormat('d MMM y', Store.i.lang.value).format(DateTime.now());
  switch (id) {
    case 'journal':
      return _ar ? 'يوميات $date' : 'Journal $date';
    case 'meeting':
      return _ar ? 'اجتماع $date' : 'Meeting $date';
    case 'shopping':
      return _ar ? 'قائمة المشتريات' : 'Shopping list';
    default:
      return _ar ? 'خطة يوم $date' : 'Plan for $date';
  }
}

List<_Row> _rows(String id) {
  switch (id) {
    case 'journal':
      return _ar
          ? const [
              _Row('ماذا حدث اليوم؟', 'h'),
              _Row(''),
              _Row('أنا ممتن لـ', 'h'),
              _Row('', 'bullet'),
              _Row('ما تعلّمته', 'h'),
              _Row(''),
              _Row('خطة بكرة', 'h'),
              _Row('', 'todo'),
            ]
          : const [
              _Row('What happened today?', 'h'),
              _Row(''),
              _Row("I'm grateful for", 'h'),
              _Row('', 'bullet'),
              _Row('What I learned', 'h'),
              _Row(''),
              _Row("Tomorrow's plan", 'h'),
              _Row('', 'todo'),
            ];
    case 'meeting':
      return _ar
          ? const [
              _Row('الحضور', 'h'),
              _Row('', 'bullet'),
              _Row('النقاط الرئيسية', 'h'),
              _Row('', 'bullet'),
              _Row('القرارات', 'h'),
              _Row('', 'bullet'),
              _Row('المهام المطلوبة', 'h'),
              _Row('', 'todo'),
            ]
          : const [
              _Row('Attendees', 'h'),
              _Row('', 'bullet'),
              _Row('Key points', 'h'),
              _Row('', 'bullet'),
              _Row('Decisions', 'h'),
              _Row('', 'bullet'),
              _Row('Action items', 'h'),
              _Row('', 'todo'),
            ];
    case 'shopping':
      return _ar
          ? const [
              _Row('', 'todo'),
              _Row('', 'todo'),
              _Row('', 'todo'),
            ]
          : const [
              _Row('', 'todo'),
              _Row('', 'todo'),
              _Row('', 'todo'),
            ];
    default:
      return _ar
          ? const [
              _Row('أهم 3 أولويات', 'h'),
              _Row('', 'todo'),
              _Row('', 'todo'),
              _Row('', 'todo'),
              _Row('الصباح', 'h'),
              _Row('', 'todo'),
              _Row('الظهر', 'h'),
              _Row('', 'todo'),
              _Row('المساء', 'h'),
              _Row('', 'todo'),
            ]
          : const [
              _Row('Top 3 priorities', 'h'),
              _Row('', 'todo'),
              _Row('', 'todo'),
              _Row('', 'todo'),
              _Row('Morning', 'h'),
              _Row('', 'todo'),
              _Row('Afternoon', 'h'),
              _Row('', 'todo'),
              _Row('Evening', 'h'),
              _Row('', 'todo'),
            ];
  }
}

/// Quill delta (JSON list) for the template.
List<Map<String, dynamic>> templateDelta(String id) {
  final ops = <Map<String, dynamic>>[];
  for (final r in _rows(id)) {
    if (r.text.isNotEmpty) ops.add({'insert': r.text});
    Map<String, dynamic>? attrs;
    if (r.kind == 'h') attrs = {'header': 3};
    if (r.kind == 'todo') attrs = {'list': 'unchecked'};
    if (r.kind == 'bullet') attrs = {'list': 'bullet'};
    ops.add({'insert': '\n', if (attrs != null) 'attributes': attrs});
  }
  return ops;
}

/// Plain text version, used when the note already has content.
String templatePlain(String id) =>
    _rows(id).where((r) => r.text.isNotEmpty).map((r) => r.text).join('\n');
