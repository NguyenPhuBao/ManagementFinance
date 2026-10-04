plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.flowmoney.flowmoney"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Bắt buộc cho flutter_local_notifications (từ bản 10 trở đi), kể cả
        // khi chưa dùng lịch đặt trước. Thiếu nó thì build DEBUG vẫn chạy còn
        // build RELEASE gãy với thông báo lỗi nói về java.time — rất khó lần
        // ngược về nguyên nhân.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.flowmoney.flowmoney"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Đi kèm `isCoreLibraryDesugaringEnabled` ở trên — hai thứ này phải có
    // cùng nhau, thiếu một là lỗi build.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Nhắc ghi sau khi dùng app ngân hàng: kiểm định kỳ 15 phút. ĐÚNG bản `background_downloader` 9.6.3 đang kéo vào
    // (`implementation` của plugin không lộ ra module app) — trùng bản, không xung đột.
    implementation("androidx.work:work-runtime-ktx:2.11.0")
}

flutter {
    source = "../.."
}
