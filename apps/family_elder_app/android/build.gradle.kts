allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (file_picker, geolocator via flutter_plugin_android_lifecycle)
// ship AARs that require consumers to compile against Android 36. Plugin
// modules do NOT inherit the app module's compileSdk, so force every Android
// subproject to compileSdk 36 here. Done reflectively so it works across AGP
// API versions without a compile-time dependency on AGP classes.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        try {
            androidExt.javaClass
                .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                .invoke(androidExt, 36)
        } catch (_: Throwable) {
            try {
                androidExt.javaClass
                    .getMethod("compileSdkVersion", String::class.java)
                    .invoke(androidExt, "android-36")
            } catch (_: Throwable) {
                // Leave as-is if neither setter exists.
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
