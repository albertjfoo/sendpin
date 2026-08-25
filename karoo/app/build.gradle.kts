import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

// Signing config lives outside the repo. keystore.properties is gitignored, so
// a clone without it still builds -- it just falls back to debug signing, which
// is right for contributors and wrong for releases.
//
// Android refuses an update whose signature does not match what is already
// installed, so every published release must be signed with the same key or
// users have to uninstall first.
val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) keystorePropsFile.inputStream().use { load(it) }
}
val hasReleaseSigning = keystorePropsFile.exists() &&
    keystoreProps.getProperty("storePassword").orEmpty().isNotBlank() &&
    keystoreProps.getProperty("storePassword") != "PUT_YOUR_PASSWORD_HERE"

android {
    namespace = "app.sendpin"
    compileSdk = 35

    defaultConfig {
        applicationId = "app.sendpin"
        // The Karoo 2 runs Android 8.1.0 / API 27. Verified on the unit
        // 2026-08-06 via `getprop ro.build.version.sdk`. Do not raise this.
        minSdk = 27
        targetSdk = 35
        versionCode = 2
        versionName = "0.2"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    sourceSets["main"].java.srcDirs("src/main/kotlin")
}

dependencies {
    implementation(libs.karoo.ext)
    implementation(libs.kotlinx.coroutines.android)
}
