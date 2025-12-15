plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")        // <-- usa el id oficial
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sodim"

    // Requerido por mobile_scanner 6.x (CameraX)
    compileSdk = 36

    // Quita si no usas NDK
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.sodim"

        // CameraX exige al menos 23
        minSdk = 23

        // Puedes dejar 34 (recomendado hoy) o subir cuando migres
        targetSdk = 34

        // Toma versionCode/Name desde Flutter (mantén estas líneas)
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Con minSdk 23 no es estrictamente necesario, pero no estorba
        multiDexEnabled = true
    }

    // Java 17 (alineado con AGP y Kotlin 2.1)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
            // ⚠️ cámbialo a tu signingConfig de release cuando firmes
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.crypto.tink:tink-android:1.6.1")
    implementation("joda-time:joda-time:2.10.10")
    implementation("org.joda:joda-convert:2.2.1")
    implementation("com.squareup.okhttp3:okhttp:4.9.3")
    // Con minSdk 23 no necesitas androidx.multidex explícito
}
