plugins {
    id("com.android.application")
    kotlin("android")
}

setupApp()

android {
    namespace = "io.github.madeye.meow"

    defaultConfig {
        applicationId = "io.github.madeye.meow"
    }
}

dependencies {
    coreLibraryDesugaring(libs.desugar)
    implementation(project(":flutter"))
}
