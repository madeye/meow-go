import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    kotlin("android")
}

setupApp()

val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

fun prop(key: String): String? =
    localProps.getProperty(key) ?: System.getenv(key)

android {
    namespace = "io.github.madeye.meow"

    defaultConfig {
        applicationId = "io.github.madeye.meow"
    }

    val keystorePath = prop("KEYSTORE_PATH")
    val keystoreFile = keystorePath?.let { File(it) }

    if (keystoreFile != null && keystoreFile.exists()) {
        signingConfigs {
            create("release") {
                storeFile = keystoreFile
                storePassword = prop("KEYSTORE_PASSWORD")
                keyAlias = prop("KEY_ALIAS")
                keyPassword = prop("KEY_PASSWORD")
            }
        }
        buildTypes {
            getByName("release") {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring(libs.desugar)
    implementation(project(":flutter"))
}
