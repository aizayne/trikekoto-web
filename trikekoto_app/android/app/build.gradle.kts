import java.util.Properties

// Release signing credentials, kept out of the repository.
//
// android/key.properties is gitignored and holds the keystore password. When
// it is absent — a fresh clone, or CI without secrets — the release build
// falls back to debug signing so `flutter build apk` still works. That APK
// installs fine for sideloading but must never be the one handed to drivers:
// its signing identity is Android's shared debug key.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ph.trikekoto.trikekoto_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ph.trikekoto.trikekoto_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Loud on purpose: a debug-signed APK is indistinguishable
                // from a real one until you try to update it.
                logger.warn(
                    "WARNING: android/key.properties not found. " +
                    "This APK is DEBUG-SIGNED and must not be distributed. " +
                    "See README 'Release signing' to create a keystore."
                )
                signingConfigs.getByName("debug")
            }

            // Always on. Flutter enables shrinking for release by default,
            // and tying it to the keystore silently added ~5 MB to every
            // test build — which matters when the APK is sideloaded over
            // Wi-Fi. Test builds should also exercise the same shrinking a
            // real release gets, or R8 problems only surface at release.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
