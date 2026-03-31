plugins {
    id("com.android.library")
    id("com.google.devtools.ksp")
    id("org.mozilla.rust-android-gradle.rust-android")
    kotlin("android")
    id("kotlin-parcelize")
}

setupCore()

val allAbis = mapOf("arm" to "armeabi-v7a", "arm64" to "arm64-v8a", "x86" to "x86", "x86_64" to "x86_64")
val targetAbi = findProperty("TARGET_ABI")?.toString()

android {
    namespace = "io.github.madeye.meow.core"

    defaultConfig {
        consumerProguardFiles("proguard-rules.pro")

        ksp {
            arg("room.incremental", "true")
            arg("room.schemaLocation", "$projectDir/schemas")
        }
    }

    sourceSets.getByName("androidTest") {
        assets.setSrcDirs(assets.srcDirs + files("$projectDir/schemas"))
    }

    buildFeatures.aidl = true
}

cargo {
    module = "src/main/rust/mihomo-android-ffi"
    libname = "mihomo_android_ffi"
    targets = if (targetAbi != null) listOf(targetAbi) else listOf("arm", "arm64", "x86", "x86_64")
    profile = findProperty("CARGO_PROFILE")?.toString() ?: currentFlavor
    exec = { spec, toolchain ->
        run {
            try {
                Runtime.getRuntime().exec(arrayOf("python3", "-V"))
                spec.environment("RUST_ANDROID_GRADLE_PYTHON_COMMAND", "python3")
            } catch (e: java.io.IOException) {
                try {
                    Runtime.getRuntime().exec(arrayOf("python", "-V"))
                    spec.environment("RUST_ANDROID_GRADLE_PYTHON_COMMAND", "python")
                } catch (e: java.io.IOException) {
                    throw GradleException("Python not found. Install Python to compile this project.")
                }
            }
            spec.environment("RUST_ANDROID_GRADLE_CC_LINK_ARG", "-Wl,-z,max-page-size=16384")
        }
    }
}

tasks.whenTaskAdded {
    when (name) {
        "mergeDebugJniLibFolders", "mergeReleaseJniLibFolders" -> {
            dependsOn("cargoBuild")
            inputs.dir(layout.buildDirectory.dir("rustJniLibs/android"))
        }
    }
}

tasks.register<Exec>("cargoClean") {
    executable("cargo")
    args("clean")
    workingDir("$projectDir/${cargo.module}")
}
tasks.named("clean").configure { dependsOn("cargoClean") }

dependencies {
    api(libs.androidx.core.ktx)
    api(libs.androidx.lifecycle.livedata.core.ktx)
    api(libs.androidx.preference)
    api(libs.androidx.room.runtime)
    api(libs.androidx.work.multiprocess)
    api(libs.androidx.work.runtime.ktx)
    api(libs.kotlinx.coroutines.android)
    api(libs.material)
    api(libs.timber)
    coreLibraryDesugaring(libs.desugar)
    ksp(libs.androidx.room.compiler)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit.ktx)
    androidTestImplementation(libs.androidx.room.testing)
    androidTestImplementation(libs.androidx.test.runner)
}
