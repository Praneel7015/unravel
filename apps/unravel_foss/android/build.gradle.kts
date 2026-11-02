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

// file_picker still compiles against API 34, while its AndroidX dependency
// requires 36. The app already uses 36, so library modules follow it.
fun Project.alignCompileSdk() {
    val android = extensions.findByName("android") ?: return
    val getter = android.javaClass.methods.find { method ->
        method.name == "getCompileSdk" && method.parameterCount == 0
    } ?: return
    val current = getter.invoke(android) as? Int ?: return
    if (current < 36) {
        val setter = android.javaClass.methods.find { method ->
            method.name == "setCompileSdk" && method.parameterCount == 1
        } ?: return
        setter.invoke(android, 36)
    }
}

subprojects {
    if (state.executed) {
        alignCompileSdk()
    } else {
        afterEvaluate { alignCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
