"""Run after `flutter create --platforms=android .`
Patches the generated Android project for: scheduled notifications,
microphone recording, core-library desugaring, minSdk and the app label."""
import glob
import os
import re

# ---- AndroidManifest.xml ---------------------------------------------------
path = "android/app/src/main/AndroidManifest.xml"
xml = open(path, encoding="utf-8").read()

perms = """
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
"""
receivers = """
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"/>
        <receiver android:exported="true"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""

if "ScheduledNotificationReceiver" not in xml:
    xml = re.sub(r"(<manifest[^>]*>)", r"\1" + perms, xml, count=1)
    xml = xml.replace("</application>", receivers + "    </application>", 1)

xml = re.sub(r'android:label="[^"]*"', 'android:label="Joe&apos;s Notes"', xml, count=1)

# speech recognition (dictation) must be visible on Android 11+
if "android.speech.RecognitionService" not in xml:
    q = '<intent><action android:name="android.speech.RecognitionService"/></intent>'
    if "<queries>" in xml:
        xml = xml.replace("<queries>", "<queries>\n        " + q, 1)
    else:
        xml = xml.replace("</manifest>", "    <queries>\n        " + q + "\n    </queries>\n</manifest>", 1)

# receive text shared from other apps ("Share" -> Joe's Notes)
if "android.intent.action.SEND" not in xml:
    share = """
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/plain"/>
            </intent-filter>
        """
    xml = xml.replace("</activity>", share + "</activity>", 1)
open(path, "w", encoding="utf-8").write(xml)

# ---- app/build.gradle(.kts) -----------------------------------------------
gradle = None
for cand in glob.glob("android/app/build.gradle*"):
    gradle = cand
    break
assert gradle, "app build.gradle not found"
src = open(gradle, encoding="utf-8").read()

if gradle.endswith(".kts"):
    if "isCoreLibraryDesugaringEnabled" not in src:
        src = src.replace(
            "compileOptions {",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            1,
        )
        src += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    src = src.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
else:
    if "coreLibraryDesugaringEnabled" not in src:
        src = src.replace(
            "compileOptions {",
            "compileOptions {\n        coreLibraryDesugaringEnabled true",
            1,
        )
        src += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    src = src.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 24")


# ---- release signing (fixed key, so updates install over older versions) ----
if os.environ.get("KEYSTORE_PATH") and os.environ.get("KEY_ALIAS"):
    is_kts = gradle.endswith(".kts")
    if is_kts:
        block = """    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KEYSTORE_PATH"))
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }
    buildTypes {"""
        src = src.replace("    buildTypes {", block, 1)
        src = src.replace('signingConfig = signingConfigs.getByName("debug")',
                          'signingConfig = signingConfigs.getByName("release")')
    else:
        block = """    signingConfigs {
        release {
            storeFile file(System.getenv("KEYSTORE_PATH"))
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }
    buildTypes {"""
        src = src.replace("    buildTypes {", block, 1)
        src = src.replace("signingConfig signingConfigs.debug",
                          "signingConfig signingConfigs.release")
    assert "signingConfigs" in src and "getByName(\"release\")" in src or "signingConfigs.release" in src, "signing patch failed"
    print("Release signing enabled")
else:
    print("WARNING: no signing key, using debug key")

open(gradle, "w", encoding="utf-8").write(src)
print("Android project patched:", gradle)

# ---- force compileSdk 36 on every plugin (some pin older versions) ----------
root = None
for cand in ("android/build.gradle.kts", "android/build.gradle"):
    if os.path.exists(cand):
        root = cand
        break
assert root, "root build.gradle not found"
rsrc = open(root, encoding="utf-8").read()
if "joes-compile-sdk" not in rsrc:
    if root.endswith(".kts"):
        fix = """// joes-compile-sdk
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.withGroovyBuilder {
            "compileSdkVersion"(36)
        }
    }
}

"""
    else:
        fix = """// joes-compile-sdk
subprojects {
    afterEvaluate { p ->
        if (p.hasProperty('android')) {
            p.android.compileSdkVersion 36
        }
    }
}

"""
    marker = "subprojects {"
    if marker in rsrc:
        i = rsrc.index(marker)
        rsrc = rsrc[:i] + fix + rsrc[i:]
    else:
        rsrc += "\n" + fix
    open(root, "w", encoding="utf-8").write(rsrc)
    print("compileSdk 36 forced via", root)

# ---- MainActivity: FragmentActivity (fingerprint prompt) + share channel ----
kt_files = glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True)
assert kt_files, "MainActivity.kt not found"
kt = kt_files[0]
pkg = re.search(r"^package\s+([\w.]+)", open(kt, encoding="utf-8").read(), re.M).group(1)
open(kt, "w", encoding="utf-8").write("""package %s

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var pending: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        readShared(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "joes/share")
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getShared") {
                result.success(pending)
                pending = null
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readShared(intent)
        val text = pending
        if (text != null) {
            channel?.invokeMethod("shared", text)
            pending = null
        }
    }

    private fun readShared(i: Intent?) {
        if (i != null && i.action == Intent.ACTION_SEND && i.type?.startsWith("text/") == true) {
            pending = i.getStringExtra(Intent.EXTRA_TEXT)
        }
    }
}
""" % pkg)
print("MainActivity patched:", kt)

# local_auth's prompt needs an AppCompat theme on the launch activity
for st in glob.glob("android/app/src/main/res/values*/styles.xml"):
    x = open(st, encoding="utf-8").read()
    y = re.sub(r'(<style name="(?:LaunchTheme|NormalTheme)" parent=")[^"]+(")',
               r'\1Theme.AppCompat.DayNight.NoActionBar\2', x)
    if y != x:
        open(st, "w", encoding="utf-8").write(y)
        print("theme patched:", st)
