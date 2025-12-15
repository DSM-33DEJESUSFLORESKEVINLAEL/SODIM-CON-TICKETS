pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // (Opcional) puedes declarar plugins aquí también;
    // pero mantenerlos abajo con 'apply false' está bien.
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // ✅ Android Gradle Plugin (AGP) compatible con Gradle 8.10.x
    id("com.android.application") version "8.7.3" apply false
    // También podrías usar "8.7.0" si prefieres, pero 8.7.3 es estable reciente.

    // ✅ Kotlin 2.1.x para que mobile_scanner (stdlib 2.1.0) compile sin errores
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
