# Keep Flutter entrypoints
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep classes used by reflection in some plugins
-keepclassmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator CREATOR;
}

# Keep Play Core classes used for deferred components
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ===== AJOUTS POUR HTTP/RÉSEAU =====

# Keep HTTP classes
-keep class org.apache.http.** { *; }
-dontwarn org.apache.http.**
-dontwarn org.apache.commons.**

# Keep OkHttp (utilisé par Flutter pour HTTP)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep Retrofit/Gson si vous les utilisez
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep les classes de modèles de données (adaptez selon vos packages)
-keep class com.example.mhbeauty.models.** { *; }
-keep class * extends com.google.gson.TypeAdapter

# SSL/TLS
-keep class javax.net.ssl.** { *; }
-keep class org.conscrypt.** { *; }
-dontwarn javax.net.ssl.**
-dontwarn org.conscrypt.**

# Keep les attributs pour la serialization JSON
-keepattributes *Annotation*, InnerClasses
-keepattributes Signature, Exception

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep les enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}