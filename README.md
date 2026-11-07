# Joe's Notes

تطبيق ملاحظات + مهام + أفكار (Flutter، أندرويد). ثيم AMOLED أسود، عربي/إنجليزي.

## بناء ملف APK بدون كمبيوتر (GitHub)
1. أنشئ مستودع جديد على GitHub وارفع كل محتويات هذا المجلد (بما فيها مجلد `.github`).
2. افتح تبويب **Actions** ← **Build APK** ← **Run workflow**.
3. بعد دقائق، افتح التشغيل ونزّل **joes-notes-apk** من أسفل الصفحة، فك الضغط وثبّت `app-release.apk`.

## أو على جهازك
```
flutter create --platforms=android --org com.joe --project-name joes_notes .
python3 tool/patch_android.py
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```

## ملاحظات
- الأيقونة: `assets/icon.png` (أعد توليدها بـ `python3 tool/make_icon.py`).
- التنبيهات: عند أول تشغيل وافق على إذن الإشعارات وإذن "المنبهات والتذكيرات".
  بعض الهواتف (شاومي، أوبو، سامسونج...) توقف التطبيقات في الخلفية، فاستثنِ التطبيق من توفير البطارية.
- البيانات محفوظة على الجهاز فقط.
