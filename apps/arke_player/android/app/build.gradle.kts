import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key for a signed APK lives outside the repository. `android/key.properties` (gitignored)
// names it: storeFile, storePassword, keyAlias, keyPassword. CI writes one naming its own test key.
// Without it a release build falls back to the debug key, so a fresh clone still builds
// (docs/mvp.md, Decided 2).
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) FileInputStream(file).use { load(it) }
}

// Use Flutter's same build definition for both the native identity and Dart code.
// A dev APK must coexist with production without replacing its library or jobs.
val channelValues = (project.findProperty("dart-defines") as? String).orEmpty()
    .split(',').filter { it.isNotEmpty() }
    .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
    .filter { it.startsWith("ARKE_CATALOGUE_CHANNEL=") }
    .map { it.substringAfter('=') }
require(channelValues.size <= 1) { "Duplicate ARKE_CATALOGUE_CHANNEL definitions" }
val catalogueChannel = channelValues.singleOrNull() ?: "production"
require(catalogueChannel in listOf("production", "development")) { "Unknown ARKE_CATALOGUE_CHANNEL" }

android {
    namespace = "studio.arke.arke_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules with java.time, which older Androids get desugared.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = if (catalogueChannel == "development") "studio.arke.player.dev" else "studio.arke.player"
        manifestPlaceholders["arkeAppLabel"] = if (catalogueChannel == "development") "Arke Player Dev" else "Arke Player"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyProperties.containsKey("storeFile")) {
            create("upload") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
