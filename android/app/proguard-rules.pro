# No eliminar anotaciones necesarias
-keep class com.google.errorprone.annotations.** { *; }
-keep class javax.annotation.** { *; }
-keep class javax.annotation.concurrent.** { *; }

# Mantener clases de Tink (sin KeysDownloader)
-keep class com.google.crypto.tink.** { *; }

# Mantener clases de Joda-Time
-keep class org.joda.time.** { *; }

# Ignorar completamente KeysDownloader y evitar analizar sus métodos
-assumenosideeffects class com.google.crypto.tink.util.KeysDownloader {
    *;
}

# Evitar que R8 falle por referencias a Google API Client (que no usamos)
-dontwarn com.google.api.client.http.**

# Evitar que R8 falle por anotaciones faltantes de ErrorProne (solo avisos)
-dontwarn com.google.errorprone.annotations.**

# Evitar que R8 falle por javax.lang.model.element.Modifier (solo necesario para compilación de librerías de Google, no para tu app)
-dontwarn javax.lang.model.element.**

# Evitar que R8 falle por clases de Google Play Core (SplitCompat)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }


# ================================================
# Mantener tus clases del proyecto Flutter
# ================================================

# Paquete real de tu app
-keep class com.example.miapp.** { *; }

# Mantener los miembros de las clases (JSON, SQLite)
-keepclassmembers class com.example.miapp.** { *; }

# Protege las anotaciones usadas por json_serializable
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Protege clases de Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }