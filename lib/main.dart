import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:intl/date_symbol_data_local.dart';

import 'l10n.dart';
import 'notifier.dart';
import 'pages/ideas_page.dart';
import 'pages/notes_page.dart';
import 'pages/tasks_page.dart';
import 'store.dart';
import 'widgets.dart';

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
    return ValueListenableBuilder<String>(
      valueListenable: Store.i.lang,
      builder: (context, lang, _) {
        return MaterialApp(
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
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.black, // AMOLED
            canvasColor: Colors.black,
            colorScheme: const ColorScheme.dark(
              primary: kOrange,
              onPrimary: Colors.black,
              surface: Colors.black,
              surfaceContainerHighest: Color(0xFF1A1A1A),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
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

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final titles = [t('notes'), t('tasks'), t('ideas')];
    final lang = Store.i.lang.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
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
                      TextButton(
                        onPressed: () =>
                            Store.i.setLang(lang == 'ar' ? 'en' : 'ar'),
                        child: Text(
                          lang == 'ar' ? 'EN' : 'ع',
                          style: const TextStyle(
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
                    children: const [NotesPage(), TasksPage(), IdeasPage()],
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
  }
}
