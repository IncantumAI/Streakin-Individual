allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force all plugin subprojects to compileSdk 37.
// Required by super_keyboard (via super_editor) and flutter_plugin_android_lifecycle.
subprojects {
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            val android = extensions.getByType(com.android.build.gradle.BaseExtension::class)
            android.compileSdkVersion(37)
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
