plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.ghurabaa"
    compileSdk = 36 // يجب أن تكون 36 لتلبية متطلبات المكتبات الحديثة

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.ghurabaa"
        minSdk = flutter.minSdkVersion
        targetSdk = 36 // يجب أن تطابق compileSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// حل تعارضات الإصدارات للمكتبات
configurations.all {
    resolutionStrategy {
        eachDependency {
            if (requested.group == "androidx.core" || requested.group == "androidx.lifecycle") {
                useVersion("2.8.0")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
