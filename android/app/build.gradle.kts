plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.offlinemobileide.aioide"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.offlinemobileide.aioide"
        // Minimum Android 8.0 — required for foreground service APIs,
        // EncryptedSharedPreferences, and baseline storage access.
        // Architecture: 01-REQUIREMENTS.md CON-002
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            buildConfigField("boolean", "ENABLE_VERBOSE_LOGGING", "true")
            buildConfigField("boolean", "PERSIST_LOGS_TO_FILE", "true")
        }
        release {
            buildConfigField("boolean", "ENABLE_VERBOSE_LOGGING", "false")
            buildConfigField("boolean", "PERSIST_LOGS_TO_FILE", "false")
            // AGP 9.x requires shrinkResources and minifyEnabled to be set together.
            // Both are disabled for now — enable before Play Store release.
            isMinifyEnabled = false
            isShrinkResources = false
            // TODO: replace with a real signing config before release
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    buildFeatures {
        buildConfig = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Secure API key storage via Android Keystore.
    // Architecture: 06-SECURITY.md §11.1
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // ActivityResultLauncher for SAF file/directory pickers.
    // Architecture: 02-ARCHITECTURE.md §9.2
    implementation("androidx.activity:activity-ktx:1.9.3")
}
