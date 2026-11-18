import java.io.File
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional production signing, mirroring twese-android's CI convention.
// In CI the keystore is supplied as a base64 GitHub Secret; without it we keep
// Flutter's default debug-signed release so local/`flutter build apk` still works.
val keystoreBase64 = System.getenv("KEYSTORE_BASE64")
val keystorePassword = System.getenv("KEYSTORE_PASSWORD")
val keyAlias = System.getenv("KEY_ALIAS")
val keyPassword = System.getenv("KEY_PASSWORD")
val hasReleaseKeystore = !keystoreBase64.isNullOrBlank() &&
    !keystorePassword.isNullOrBlank() &&
    !keyAlias.isNullOrBlank() &&
    !keyPassword.isNullOrBlank()

if (hasReleaseKeystore) {
    val keystoreDir = File(rootProject.projectDir, ".gradle/keystores")
    keystoreDir.mkdirs()
    val keystoreFile = File(keystoreDir, "release.jks")
    keystoreFile.writeBytes(Base64.getMimeDecoder().decode(keystoreBase64))
    keystoreFile.setReadable(true, true)
    keystoreFile.setWritable(true, true)
}

android {
    namespace = "com.example.fleetman"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = File(rootProject.projectDir, ".gradle/keystores/release.jks")
                storePassword = keystorePassword
                keyAlias = keyAlias
                keyPassword = keyPassword
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.fleetman"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (signingConfigs.findByName("release") != null) {
                signingConfigs.getByName("release")
            } else {
                // Signing with the debug keys for now, so `flutter run --release` works.
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

flutter {
    source = "../.."
}
