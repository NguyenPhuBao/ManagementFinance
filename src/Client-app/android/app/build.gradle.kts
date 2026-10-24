import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Khoá ký bản phát hành (2026-10-24, siết bảo mật đợt 3): `android/key.properties` (gitignore cùng `*.jks`) trỏ tới
// keystore thật — có thì ký bằng nó; KHÔNG có thì vẫn ký debug để máy nào cũng dựng được bản release để thử (đo R8, đo
// máy thật), kèm cảnh báo. Mẫu tệp + lệnh keytool: mục *Lệnh hay dùng* `CLAUDE.md`. Không đưa APK ký debug cho người dùng.
val tepKhoaPhatHanh = rootProject.file("key.properties")
val khoaPhatHanh = Properties().apply {
    if (tepKhoaPhatHanh.exists()) FileInputStream(tepKhoaPhatHanh).use { load(it) }
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

    signingConfigs {
        if (tepKhoaPhatHanh.exists()) {
            create("release") {
                keyAlias = khoaPhatHanh["keyAlias"] as String
                keyPassword = khoaPhatHanh["keyPassword"] as String
                storeFile = file(khoaPhatHanh["storeFile"] as String)
                storePassword = khoaPhatHanh["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (tepKhoaPhatHanh.exists()) {
                signingConfigs.getByName("release")
            } else {
                // `quiet`, không `warn`: `flutter build` gọi Gradle ở chế độ im — `warn` không bao giờ hiện (đo 2026-10-24).
                if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
                    logger.quiet(
                        "⚠️ FlowMoney: không có android/key.properties — bản release ký bằng khoá DEBUG " +
                            "(chỉ để thử trên máy, KHÔNG phát hành)."
                    )
                }
                signingConfigs.getByName("debug")
            }
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
