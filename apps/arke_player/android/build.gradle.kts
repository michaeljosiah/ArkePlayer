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
// fails Kotlin's JVM-target check. Each plugin's Kotlin follows that plugin's own Java target, so
// both halves of a module agree whatever the plugin declares.
fun Project.alignKotlinWithJava() {
    val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension ?: return
    val javaTarget = android.compileOptions.targetCompatibility.toString()
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget))
    }
}
subprojects {
    // :app is evaluated early (evaluationDependsOn above), and afterEvaluate refuses a project that is.
    if (state.executed) alignKotlinWithJava() else afterEvaluate { alignKotlinWithJava() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
