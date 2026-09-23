package com.flowmoney.flowmoney

import android.app.ActivityManager
import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

/**
 * Kênh `flowmoney/luu_tep` — lưu tệp báo cáo vào thư mục **Tải về** của máy.
 *
 * Vì sao cần mã gốc: đặt một tệp vào bộ nhớ chung mà không xin quyền chỉ làm
 * được qua `MediaStore` (Android 10+, API 29). Mọi cách khác đều đòi
 * `WRITE_EXTERNAL_STORAGE` — quyền mà Android đã thu hồi tác dụng từ API 29 —
 * hoặc đẩy người dùng qua một hộp thoại chọn thư mục.
 *
 * Máy dưới API 29 trả mã `khong_ho_tro`; phía Dart khi ấy lùi về sheet chia sẻ.
 *
 * Kênh `flowmoney/ly_do_thoat` — canary phiên có tool của trợ lý AI (bước 1b,
 * 2026-09-23): phía Dart hỏi **vì sao** lần trước app chết, để phân biệt một cú
 * sập native của engine mô hình với việc app bị giết (Realme giết app khi vuốt
 * khỏi Recents, hệ điều hành giết khi thiếu RAM, người dùng bấm Buộc dừng).
 * Xem `lib/features/ai_edge/domain/canary_cong_cu.dart`.
 */
class MainActivity : FlutterActivity() {
    private val kenhLuuTep = "flowmoney/luu_tep"
    private val kenhLyDoThoat = "flowmoney/ly_do_thoat"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kenhLuuTep)
            .setMethodCallHandler { call, ket ->
                if (call.method != "luuVaoTaiVe") {
                    ket.notImplemented()
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    ket.error("khong_ho_tro", "Cần Android 10 trở lên", null)
                    return@setMethodCallHandler
                }
                try {
                    val ten = call.argument<String>("ten")!!
                    val mime = call.argument<String>("mime")!!
                    val bytes = call.argument<ByteArray>("bytes")!!
                    ket.success(luuVaoTaiVe(ten, mime, bytes))
                } catch (e: Exception) {
                    ket.error("loi_ghi", e.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kenhLyDoThoat)
            .setMethodCallHandler { call, ket ->
                if (call.method != "thongTin") {
                    ket.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    ket.success(thongTinThoat())
                } catch (e: Exception) {
                    ket.error("loi_doc", e.message, null)
                }
            }
    }

    /**
     * `phienBan` — `versionCode` của app: dấu "hỏng" của canary ghi số này và tự
     * xoá khi app lên bản mới. `lanThoat` — các lần tiến trình của app chết gần
     * đây (`ApplicationExitInfo`, chỉ có từ Android 11 / API 30), mỗi lần một cặp
     * `lyDo` (hằng `REASON_*`) và `luc` (mili giây epoch); `null` trên máy cũ hơn
     * — phía Dart đọc là "không biết" và rơi về luật hai lần liền.
     */
    @Suppress("DEPRECATION")
    private fun thongTinThoat(): Map<String, Any?> {
        val goi = packageManager.getPackageInfo(packageName, 0)
        val phienBan: Long =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) goi.longVersionCode
            else goi.versionCode.toLong()
        val lanThoat: List<Map<String, Any>>? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                getSystemService(ActivityManager::class.java)
                    .getHistoricalProcessExitReasons(packageName, 0, 16)
                    .map { mapOf("lyDo" to it.reason, "luc" to it.timestamp) }
            } else {
                null
            }
        return mapOf("phienBan" to phienBan, "lanThoat" to lanThoat)
    }

    /**
     * Trả về đường dẫn hiển thị của tệp vừa lưu.
     *
     * `IS_PENDING` bật trong lúc ghi rồi mới tắt: không có nó, ứng dụng khác
     * nhìn thấy tệp khi nội dung còn đang dở. MediaStore tự đổi tên khi trùng
     * (`BaoCao (1).pdf`), nên không cần tự kiểm.
     */
    private fun luuVaoTaiVe(ten: String, mime: String, bytes: ByteArray): String {
        val gt = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, ten)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, gt)
            ?: throw IOException("Không tạo được tệp trong thư mục Tải về")

        contentResolver.openOutputStream(uri).use { luong ->
            luong ?: throw IOException("Không mở được tệp để ghi")
            luong.write(bytes)
        }

        gt.clear()
        gt.put(MediaStore.Downloads.IS_PENDING, 0)
        contentResolver.update(uri, gt, null, null)

        return "Tải về/$ten"
    }
}
