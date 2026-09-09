package com.flowmoney.flowmoney

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
 */
class MainActivity : FlutterActivity() {
    private val kenhLuuTep = "flowmoney/luu_tep"

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
