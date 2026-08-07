pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode = RepositoriesMode.FAIL_ON_PROJECT_REPOS
    repositories {
        google()
        mavenCentral()
        // karoo-ext is published to GitHub Packages, which demands a token even
        // for public packages. JitPack serves the same repo built from source
        // with no credentials, verified 2026-08-06:
        //   https://jitpack.io/com/github/hammerheadnav/karoo-ext/1.1.9/... -> 200
        //   https://maven.pkg.github.com/... -> 401
        maven { url = uri("https://jitpack.io") }
    }
}

rootProject.name = "sendpin"
include(":app")
