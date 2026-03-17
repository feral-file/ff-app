import java.util.Properties
import java.io.File
import org.gradle.api.GradleException
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.feralfile.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    packaging {
        resources {
            pickFirsts.add("lib/arm64-v8a/libc++_shared.so")
            pickFirsts.add("lib/armeabi-v7a/libc++_shared.so")
            pickFirsts.add("lib/x86/libc++_shared.so")
            pickFirsts.add("lib/x86_64/libc++_shared.so")
            excludes.add("META-INF/*")
        }
        jniLibs {
            pickFirsts.add("lib/arm64-v8a/libc++_shared.so")
            pickFirsts.add("lib/armeabi-v7a/libc++_shared.so")
            pickFirsts.add("lib/x86/libc++_shared.so")
            pickFirsts.add("lib/x86_64/libc++_shared.so")
        }
    }

    defaultConfig {
        applicationId = "com.feralfile.app"
        minSdk = 29
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    androidResources {
        localeFilters.addAll(listOf("en", "US"))
    }

    signingConfigs {
        create("release") {
            try {
                val propsFile = File(rootProject.projectDir, "release.properties")
                val keystoreFile = File(rootProject.projectDir, "release.keystore")

                val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
                    it.contains("Release", ignoreCase = true)
                }

                if (!propsFile.exists() || !keystoreFile.exists()) {
                    val message =
                        "Release signing files are missing. Expected android/release.properties and android/release.keystore"
                    if (isReleaseBuildRequested) throw GradleException(message) else println("Warning: $message")
                    return@create
                }

                val props = Properties()
                propsFile.inputStream().use { props.load(it) }

                val storePassword = props.getProperty("key.store.password")
                val keyAlias = props.getProperty("key.alias")
                val keyPassword = props.getProperty("key.alias.password")

                if (storePassword.isNullOrBlank() || keyAlias.isNullOrBlank() || keyPassword.isNullOrBlank()) {
                    val message =
                        "release.properties is incomplete. Required keys: key.store.password, key.alias, key.alias.password"
                    if (isReleaseBuildRequested) throw GradleException(message) else println("Warning: $message")
                    return@create
                }

                storeFile = keystoreFile
                this.storePassword = storePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            } catch (e: GradleException) {
                throw e
            } catch (e: Exception) {
                println("Warning: Could not load signing config: ${e.message}")
            }
        }
    }

    buildFeatures {
        viewBinding = true
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
            if (rootProject.file("release.keystore").exists() && rootProject.file("release.properties").exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }

    flavorDimensions.add("env")
    productFlavors {
        create("development") {
            dimension = "env"
            applicationIdSuffix = ".inhouse"
            resValue("string", "app_name", "Feral File")
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appIconRound"] = "@mipmap/ic_launcher_round"
        }
        create("production") {
            dimension = "env"
            resValue("string", "app_name", "Feral File")
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appIconRound"] = "@mipmap/ic_launcher_round"
        }
    }

    lint {
        checkReleaseBuilds = false
    }
}

flutter {
    source = "../.."
}
