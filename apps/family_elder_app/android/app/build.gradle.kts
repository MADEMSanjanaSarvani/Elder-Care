import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase (FCM push + Google Sign-In). Reads android/app/google-services.json.
    id("com.google.gms.google-services")
}

// Release signing. If android/key.properties exists (your own upload key — see
// docs/BUILD-ANDROID.md) the release build is signed with it; otherwise it
// falls back to the debug key so CI test builds still work without a keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.projectsetu.family_elder_app"
    // Some plugins (file_picker -> flutter_plugin_android_lifecycle) now
    // require compiling against Android 36; pin it here rather than relying on
    // the Flutter default.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // CareHive's unique Play Store / Google Sign-In / Firebase identity.
        // (The Kotlin `namespace` above is an internal code package and can
        // stay different from this applicationId.)
        applicationId = "in.carehive.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase (firebase_core/messaging) requires minSdk 23; pin it so the
        // Flutter default (21) doesn't fail the Firebase dependency resolution.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
