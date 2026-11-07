"""Run after `flutter create --platforms=android .`
Patches the generated Android project for: scheduled notifications,
core-library desugaring and the app label."""
import glob
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
else:
    if "coreLibraryDesugaringEnabled" not in src:
        src = src.replace(
            "compileOptions {",
            "compileOptions {\n        coreLibraryDesugaringEnabled true",
            1,
        )
        src += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
open(gradle, "w", encoding="utf-8").write(src)
print("Android project patched:", gradle)
