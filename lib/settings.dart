import 'package:flutter/material.dart';

import 'l10n.dart';
import 'lock.dart';
import 'store.dart';
import 'widgets.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111111),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(s,
            style: const TextStyle(fontSize: 13, color: Colors.white54)),
      );

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    return ListenableBuilder(
      listenable: Listenable.merge([s, s.lang, s.accent, s.bgGray, s.fontScale]),
      builder: (context, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t('settings'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                _label('${t('font_size_app')}: ${(s.fontScale.value * 100).round()}%'),
                Slider(
                  value: s.fontScale.value,
                  min: 0.85,
                  max: 1.4,
                  divisions: 11,
                  activeColor: kOrange,
                  onChanged: (v) => s.setFontScale(v),
                ),
                _label(t('accent_color')),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final c in kAccentChoices)
                      GestureDetector(
                        onTap: () {
                          s.setAccent(c);
                          Navigator.of(context).maybePop();
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c == s.accent.value
                                  ? Colors.white
                                  : Colors.white24,
                              width: c == s.accent.value ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                _label(t('background')),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(t('bg_amoled')),
                      selected: !s.bgGray.value,
                      selectedColor: kOrange.withValues(alpha: 0.35),
                      onSelected: (_) {
                        s.setBgGray(false);
                        Navigator.of(context).maybePop();
                      },
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: Text(t('bg_gray')),
                      selected: s.bgGray.value,
                      selectedColor: kOrange.withValues(alpha: 0.35),
                      onSelected: (_) {
                        s.setBgGray(true);
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: kOrange,
                  title: Text(t('app_lock')),
                  subtitle: Text(t('app_lock_sub'),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white54)),
                  value: s.appLock,
                  onChanged: (v) async {
                    if (v) {
                      if (!await deviceCanAuth()) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t('auth_unavailable'))));
                        }
                        return;
                      }
                      if (!await authenticate()) return;
                    }
                    await s.setAppLock(v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: kOrange,
                  title: Text(t('backup_reminder')),
                  value: s.backupReminder,
                  onChanged: (v) => s.setBackupReminder(v),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
