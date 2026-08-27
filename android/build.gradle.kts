allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.evaluationDependsOn(":app")
    if (state.executed) {
        bumpCompileSdk()
    } else {
        afterEvaluate { bumpCompileSdk() }
    }
}

fun Project.bumpCompileSdk() {
    val ext = extensions.findByName("android") ?: return
    try {
        ext.javaClass.getMethod("setCompileSdk", Integer.TYPE).invoke(ext, 36)
    } catch (_: NoSuchMethodException) {
        try {
            ext.javaClass.getMethod("setCompileSdkVersion", Integer.TYPE).invoke(ext, 36)
        } catch (_: Throwable) {
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
