# Flutter Engine & Play Store Deferred Components Kuralları
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Flutter & Dart Temel Saklama Kuralları
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.changes.** { *; }
-keep class io.flutter.plugin.symbol.** { *; }

# Google Mobile Ads & Hive
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.**