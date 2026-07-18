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
// subproject to compileSdk 36. Done reflectively so it works across AGP API
// versions. Because the block above evaluates :app early, some projects may
// already be evaluated when we get here — apply immediately in that case,
// otherwise defer to afterEvaluate.
subprojects {
    val forceCompileSdk = {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val attempts: List<() -> Unit> = listOf(
                {
                    androidExt.javaClass
                        .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        .invoke(androidExt, 36)
                },
                {
                    androidExt.javaClass
                        .getMethod("setCompileSdk", Integer::class.java)
                        .invoke(androidExt, Integer.valueOf(36))
                },
                {
                    androidExt.javaClass
                        .getMethod("compileSdkVersion", String::class.java)
                        .invoke(androidExt, "android-36")
                },
            )
            for (attempt in attempts) {
                try {
                    attempt()
                    break
                } catch (_: Throwable) {
                    // try the next form
                }
            }
        }
    }
    if (state.executed) {
        forceCompileSdk()
    } else {
        afterEvaluate { forceCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
