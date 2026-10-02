package com.flowmoney.flowmoney

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.webkit.MimeTypeMap
import android.widget.Toast
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Chia sẻ biên lai (spec `docs/superpowers/specs/2026-10-02-chia-se-bien-lai-design.md`):
 * mục "Ghi vào FlowMoney" trong bảng chia sẻ của app ngân hàng / ví điện tử.
 *
 * Vì sao có nó: D1 chỉ đọc thông báo đã hiện trên máy, mà chuyển khoản ngay trong
 * app ngân hàng thì app ấy không đăng thông báo biến động (người dùng báo
 * 2026-10-02). Biên lai là thứ người dùng tự đưa cho FlowMoney.
 *
 * Activity KHÔNG giao diện: chép ảnh vào `filesDir/bien_lai/`, nối MỘT dòng JSON
 * vào `filesDir/bien_lai_cho.jsonl`, báo Toast, bắn thông báo tóm tắt *không số*
 * của D1 rồi đóng ngay. Người dùng chốt: chia sẻ xong VẪN Ở app ngân hàng để còn
 * chuyển tiếp — tệp này không được mở activity nào (`bien_lai_noi_day_test.dart`
 * canh). Chữ trên ảnh được đọc phía Dart (`NhapBienLai`) khi FlowMoney mở.
 *
 * Mọi việc làm trong `onCreate` rồi `finish()`: quyền đọc `content://` của ảnh gắn
 * với vòng đời activity nhận, và theme không giao diện đòi `finish()` trước
 * `onResume`.
 *
 * Không log nội dung ảnh. Chế độ thu mẫu (chỉ bản debug) chỉ in tên gói gửi, kiểu
 * dữ liệu và kích thước.
 */
class NhanBienLaiActivity : Activity() {

    companion object {
        /** Khớp TAY với `kTepBienLaiCho` / `kThuMucBienLai` phía Dart (`nhap_bien_lai.dart`). */
        const val TEP_HANG_CHO = "bien_lai_cho.jsonl"
        const val THU_MUC = "bien_lai"

        /** Cùng `SharedPreferences` với cờ `bat` của D1. */
        const val KHOA_CO_PHIEN = "co_phien"

        private const val TRAN_BYTE = 12L * 1024 * 1024
        private const val TRAN_DANG_CHO = 20
        private const val TAG_THU = "BienLaiThu"

        /**
         * Máy đang có tài khoản đăng nhập không. Dart ghi `true` lúc
         * `NotificationScanner.start`, `false` lúc `stop`. Cờ gắn MÁY: hàng chờ
         * không mang chủ, không có phiên thì không biết biên lai thuộc về ai.
         */
        fun datCoPhien(context: Context, co: Boolean) {
            context.getSharedPreferences(BienDongListenerService.TEN_PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KHOA_CO_PHIEN, co).apply()
        }

        fun coPhien(context: Context): Boolean =
            context.getSharedPreferences(BienDongListenerService.TEN_PREFS, Context.MODE_PRIVATE)
                .getBoolean(KHOA_CO_PHIEN, false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val cau = try {
            nhan(intent)
        } catch (_: Exception) {
            "FlowMoney chỉ nhận ảnh biên lai"
        }
        Toast.makeText(applicationContext, cau, Toast.LENGTH_SHORT).show()
        finish()
    }

    /** Trả câu Toast. */
    private fun nhan(i: Intent?): String {
        if (!coPhien(this)) return "Đăng nhập FlowMoney để ghi biên lai"
        if (i?.action != Intent.ACTION_SEND) return "FlowMoney chỉ nhận ảnh biên lai"
        @Suppress("DEPRECATION")
        val uri: Uri = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else i.getParcelableExtra(Intent.EXTRA_STREAM)) ?: return "FlowMoney chỉ nhận ảnh biên lai"
        val mime = i.type ?: contentResolver.getType(uri) ?: ""
        // `android-app://<gói>` — gói của app GỬI; app không khai thì rỗng.
        val goi = referrer?.takeIf { it.scheme == "android-app" }?.host ?: ""
        if (!mime.startsWith("image/")) {
            thu("tu choi | goi=$goi | mime=$mime")
            return "FlowMoney chỉ nhận ảnh biên lai"
        }

        val hangCho = File(filesDir, TEP_HANG_CHO)
        val dangCho = if (hangCho.exists()) hangCho.readLines().count { it.isNotBlank() } else 0
        if (dangCho >= TRAN_DANG_CHO) return "Còn nhiều biên lai chưa ghi — mở FlowMoney để ghi bớt"

        val duoi = (MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "jpg")
            .filter { it.isLetterOrDigit() }.take(5).ifEmpty { "jpg" }
        val thuMuc = File(filesDir, THU_MUC).apply { mkdirs() }
        val ten = "${UUID.randomUUID()}.$duoi"
        val dich = File(thuMuc, ten)
        var tong = 0L
        var vua = false
        contentResolver.openInputStream(uri)?.use { vao ->
            dich.outputStream().use { ra ->
                val dem = ByteArray(64 * 1024)
                vua = true
                while (true) {
                    val n = vao.read(dem)
                    if (n < 0) break
                    tong += n
                    if (tong > TRAN_BYTE) {
                        vua = false
                        break
                    }
                    ra.write(dem, 0, n)
                }
            }
        }
        // "Mở được" = bộ giải mã ảnh đọc ra kích thước — một tệp mang đuôi ảnh mà không phải ảnh thì bỏ.
        val kich = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        if (vua) BitmapFactory.decodeFile(dich.path, kich)
        if (!vua || kich.outWidth <= 0) {
            dich.delete()
            thu("khong mo duoc | goi=$goi | mime=$mime | byte=$tong")
            return "FlowMoney chỉ nhận ảnh biên lai"
        }

        hangCho.appendText(
            JSONObject().put("tep", ten).put("goi", goi).put("luc", System.currentTimeMillis()).toString() + "\n"
        )
        thu("nhan | goi=$goi | mime=$mime | byte=$tong | ${kich.outWidth}x${kich.outHeight}")
        BienDongListenerService.baoTomTat(this)
        return "FlowMoney đã nhận biên lai"
    }

    /** Chế độ thu mẫu — chỉ bản debug (`FLAG_DEBUGGABLE` do hệ thống đặt theo bản build). KHÔNG nội dung ảnh. */
    private fun thu(dong: String) {
        if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) Log.d(TAG_THU, dong)
    }
}
