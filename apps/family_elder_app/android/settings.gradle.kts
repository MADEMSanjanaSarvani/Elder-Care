pluginManagement {
    val flutterSdkPath =
        run {
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
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 8.11.1 (last AGP 8) instead of 9.x: AGP 9's manifest merger
    // hard-fails on libraries that share a namespace, which every Agora AAR
    // does (io.agora.rtc across iris-rtc + full-sdk); AGP 8 only warns. 8.11.1
    // is new enough for the androidx deps (androidx.core 1.17 needs >=8.9.1)
    // and still supports compileSdk 36.
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Firebase: processes google-services.json to wire FCM + Google Sign-In.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
