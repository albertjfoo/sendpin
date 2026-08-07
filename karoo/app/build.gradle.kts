plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.albert.sendpin"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.albert.sendpin"
        // The Karoo 2 runs Android 8.1.0 / API 27. Verified on the unit
        // 2026-08-06 via `getprop ro.build.version.sdk`. Do not raise this.
        minSdk = 27
        targetSdk = 35
        versionCode = 1
        versionName = "0.1"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
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
