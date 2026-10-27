import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is configured from android/key.properties, which is written
// by CI from repository secrets and is intentionally git-ignored. When the file
// is absent (for example a PR from a fork), Gradle falls back to the debug key
// so the build still succeeds.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // Must match the Android OAuth client in Google Cloud Console. The package
    // name is part of the native Google Sign-In binding: a mismatch produces
    // ApiException 10 / a cancelled credential request.
    namespace = "com.bitaqati.app"
    // flutter_local_notifications needs API 36 to compile and API 24 to run.
    // Taking the larger of the two keeps the plugin resolvable on a Flutter
    // SDK whose defaults are older, without pinning us below Flutter's own.
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications, which uses java.time.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.bitaqati.app"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                // The committed keystore is PKCS#12, not a JKS file.
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        release {
            // CI signs with bitaqati.p12, the certificate whose SHA-1 is
            // registered in Google Cloud. A debug-signed release APK can never
            // authenticate with the Android OAuth client.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
