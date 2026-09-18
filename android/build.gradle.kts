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
// jitsi_meet_flutter_sdk pins compileSdk 34 in its own build.gradle, but the
// native Jitsi SDK it pulls in (media3 1.8, androidx.core 1.16) must be
// compiled against API 35+. Lift every plugin module to the app's compileSdk
// so the AAR metadata check passes; compileSdk only decides which APIs are
// visible at build time, not which phones can install the app.
//
// Registered before evaluationDependsOn(":app") below, because that line
// evaluates the plugin projects right away and afterEvaluate can only be
// added to a project that has not been evaluated yet. Being registered
// first also means it runs before AGP's own afterEvaluate locks the DSL.
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
                if ((compileSdk ?: 0) < 36) compileSdk = 36
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
