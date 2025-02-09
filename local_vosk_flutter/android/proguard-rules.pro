# Keep the Vosk plugin classes
-keep class com.example.local_vosk_flutter.** { *; }

# Keep Vosk library classes
-keep class org.vosk.** { *; }
-keep class org.vosk.android.** { *; }

# Keep native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all methods in the plugin
-keepclassmembers class com.example.local_vosk_flutter.LocalVoskFlutterPlugin {
    public *;
}