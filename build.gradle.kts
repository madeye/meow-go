plugins {
    alias(libs.plugins.ksp) apply false
}

buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    dependencies {
        classpath(libs.android.gradle)
        classpath(libs.kotlin.gradle)
        classpath(libs.rust.android)
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
