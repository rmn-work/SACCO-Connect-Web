pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val path = properties.getProperty("flutter.sdk")
        assert(path != null) { "flutter.sdk not set in local.properties" }
        path!!
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        val flutterSdkPath = run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            properties.getProperty("flutter.sdk")
        }
        maven {
            url = uri("$flutterSdkPath/bin/cache/artifacts/engine-gradle")
        }
    }
}

include(":app")