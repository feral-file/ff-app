plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.File

android {
    namespace = "com.feralfile.app"
    compileSdk = flutter.compileSdkVersion
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
    }

    androidResources {
        localeFilters.addAll(listOf("en", "US"))
    }

    signingConfigs {
        create("release") {
            val keystoreFile = File("${project.rootDir}/../release.keystore")
            val propsFile = File("${project.rootDir}/../release.properties")
            
            if (keystoreFile.exists() && propsFile.exists()) {
                val props = Properties()
                propsFile.inputStream().use { props.load(it) }
                
                val storePassword = props.getProperty("key.store.password")
                val keyAlias = props.getProperty("key.alias")
                val keyPassword = props.getProperty("key.alias.password")
                
                if (storePassword != null && keyAlias != null && keyPassword != null) {
                    storeFile = keystoreFile
                    this.storePassword = storePassword
                    this.keyAlias = keyAlias
                    this.keyPassword = keyPassword
                }
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
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }

    flavorDimensions.add("env")
    productFlavors {
        create("development") {
            dimension = "env"
            applicationIdSuffix = ".inhouse"
            resValue("string", "app_name", "Feral File (Dev)")
        }
        create("production") {
            dimension = "env"
            resValue("string", "app_name", "Feral File")
        }
    }

    lint {
        checkReleaseBuilds = false
    }
}

flutter {
    source = "../.."
}
