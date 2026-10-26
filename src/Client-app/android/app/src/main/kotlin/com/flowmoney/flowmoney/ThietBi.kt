package com.flowmoney.flowmoney

import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Tên máy cho header `x-device-name` (2026-10-26) — Dart đọc MỘT lần lúc dựng DI (`core/api/ten_thiet_bi.dart`).
 *
 * Đăng ký ở CẢ engine của app ([MainActivity.configureFlutterEngine]) lẫn engine headless của lượt nền
 * ([TuChuyenTien.chayHeadless]): backend thêm một dòng lịch sử thiết bị mỗi khi tên đổi, nên lượt nền thiếu kênh (gửi
 * user-agent `Dart/…`) xen giữa các lượt của app là bảng ấy phình theo từng lượt.
 */
object ThietBi {
    const val KENH = "flowmoney/thiet_bi"

    fun dangKy(messenger: BinaryMessenger) {
        MethodChannel(messenger, KENH).setMethodCallHandler { call, result ->
            if (call.method == "ten") result.success(ten()) else result.notImplemented()
        }
    }

    /** `Realme RMX2205 (Android 13)` — hãng không lặp khi tên mẫu đã mở bằng nó (`Pixel 8` của Google thì giữ hãng). */
    private fun ten(): String {
        val hang = Build.MANUFACTURER.orEmpty().trim().replaceFirstChar { it.uppercaseChar() }
        val mau = Build.MODEL.orEmpty().trim()
        val may = if (hang.isEmpty() || mau.startsWith(hang, ignoreCase = true)) mau else "$hang $mau"
        return "$may (Android ${Build.VERSION.RELEASE})"
    }
}
