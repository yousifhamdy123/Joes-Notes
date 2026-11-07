import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:intl/date_symbol_data_local.dart';

import 'backup.dart';
import 'l10n.dart';
import 'notifier.dart';
import 'pages/ideas_page.dart';
import 'pages/note_editor.dart';
import 'pages/notes_page.dart';
import 'pages/tasks_page.dart';
import 'settings.dart';
import 'share_intent.dart';
import 'store.dart';
import 'widgets.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await Store.i.load();
  await Notifier.init();
  runApp(const JoesNotesApp());
}

class JoesNotesApp extends StatelessWidget {
  const JoesNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        Store.i.lang,
        Store.i.accent,
        Store.i.bgGray,
        Store.i.fontScale,
      ]),
      builder: (context, _) {
        final lang = Store.i.lang.value;
        final accent = Color(Store.i.accent.value);
        final bg = kBg;
        return MaterialApp(
          // A new key when the look changes, so every screen repaints.
          key: ValueKey('${Store.i.accent.value}-${Store.i.bgGray.value}'),
          navigatorKey: navigatorKey,
          title: "Joe's Notes",
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(Store.i.fontScale.value),
            ),
            child: child!,
          ),
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            scaffoldBackgroundColor: bg,
            canvasColor: bg,
            colorScheme: ColorScheme.dark(
              primary: accent,
              onPrimary: Colors.black,
              surface: bg,
              surfaceContainerHighest: const Color(0xFF1A1A1A),
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: bg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF111111),
            ),
          ),
          home: const Shell(),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ShareIntent.init(_openShared);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ShareIntent.checkInitial());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A notification button may have changed tasks while the app was closed.
    if (state == AppLifecycleState.resumed) Store.i.reloadTasks();
  }

  void _openShared(String text) {
    setState(() => _i = 0);
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => NoteEditorPage(initialText: text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i.lang,
      builder: (context, _) {
        final titles = [t('notes'), t('tasks'), t('ideas')];
        final lang = Store.i.lang.value;
        return Scaffold(
          backgroundColor: kBg,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              titles[_i],
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: t('settings'),
                            onPressed: () => showSettingsSheet(context),
                            icon: const Icon(Icons.tune_rounded,
                                color: Colors.white70),
                          ),
                          IconButton(
                            tooltip: t('backup'),
                            onPressed: () => showBackupSheet(context),
                            icon: const Icon(Icons.cloud_sync_outlined,
                                color: Colors.white70),
                          ),
                          TextButton(
                            onPressed: () =>
                                Store.i.setLang(lang == 'ar' ? 'en' : 'ar'),
                            child: Text(
                              lang == 'ar' ? 'EN' : 'ع',
                              style: TextStyle(
                                color: kOrange,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _i,
                        children: const [
                          NotesPage(),
                          TasksPage(),
                          IdeasPage(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: FloatingNav(
                  index: _i,
                  onTap: (v) => setState(() => _i = v),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
