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
        versionCode = 3
        versionName = "0.3"
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

    // BuildConfig.VERSION_NAME is the single source of the version the Karoo
    // displays for this extension. Without it the version is a literal in
    // SendPinExtension.kt, which silently drifts from versionName above --
    // it already had, sitting at "0.1" against a 0.2 build.
    buildFeatures {
        buildConfig = true
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

// ── docs/manifest.json ────────────────────────────────────────────────────────
//
// What the head unit fetches for long-press → Update. Shape is karoo-ext's
// KarooAppManifest; the meta-data pointing at it is in AndroidManifest.xml.
//
// Generated rather than hand-written because it repeats the version twice, and a
// latestVersionCode that lags the published APK does not fail loudly — the
// Update button simply never lights up. That is the same drift that left the
// extension reporting "0.1" against a 0.2 build, and it is worth designing out
// once rather than remembering forever.
//
// Runs automatically after assembleRelease. Commit the result: GitHub Pages
// serves it, so it is only live once pushed.
val siteBaseUrl = "https://albertjfoo.github.io/sendpin"

val writeKarooManifest by tasks.registering {
    description = "Regenerates docs/manifest.json from the version in defaultConfig."
    group = "publishing"

    // Read into locals at configuration time so doLast holds no project reference.
    val label = "SendPin"
    val appId = android.defaultConfig.applicationId
    val vName = android.defaultConfig.versionName
    val vCode = android.defaultConfig.versionCode
    val outFile = rootProject.file("../docs/manifest.json")

    inputs.property("applicationId", appId)
    inputs.property("versionName", vName)
    inputs.property("versionCode", vCode)
    outputs.file(outFile)

    doLast {
        outFile.writeText(
            """
            {
              "label": "$label",
              "packageName": "$appId",
              "latestVersion": "$vName",
              "latestVersionCode": $vCode,
              "latestApkUrl": "$siteBaseUrl/sendpin.apk",
              "iconUrl": "$siteBaseUrl/icon.png",
              "developer": "Albert Foo",
              "description": "Send a destination from your iPhone to a Karoo 2 over Bluetooth. Share a place from Apple Maps and it opens on the Karoo's pin screen, ready to navigate.",
              "releaseNotes": "See the release notes on the SendPin site.",
              "screenshotUrls": ["$siteBaseUrl/karoo-screen.png"],
              "tags": ["navigation", "bluetooth", "iphone"]
            }

            """.trimIndent(),
        )
        logger.lifecycle("wrote ${outFile.path} (v$vName / $vCode)")
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(writeKarooManifest)
}
