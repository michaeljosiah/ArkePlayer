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

// A plugin that compiles its Java for 1.8 while Kotlin compiles for 17 (receive_sharing_intent 1.8.1)
// fails Kotlin's JVM-target check. Every plugin module compiles both for 17, set rather than read:
// AGP refuses to report a module's Java target before it is finalized. D8 turns Java 17 bytecode
// into Android code whatever the device's version.
fun Project.compileFor17() {
    extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
subprojects {
    // :app is evaluated early (evaluationDependsOn above), and afterEvaluate refuses a project that is.
    if (state.executed) compileFor17() else afterEvaluate { compileFor17() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
