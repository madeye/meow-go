plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}
include(":core", ":mobile")

// Flutter module
val flutterModuleDir = file("flutter_module")
if (flutterModuleDir.resolve(".android/include_flutter.groovy").exists()) {
    apply(from = "${flutterModuleDir}/.android/include_flutter.groovy")
}
