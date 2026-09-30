package com.flowmoney.flowmoney

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * D1 — đọc thông báo biến động số dư của ngân hàng / ví điện tử ngay trên máy
 * (spec `docs/superpowers/specs/2026-09-28-d1-doc-bien-dong-so-du-design.md` §2;
 * backend duyệt toàn diện 2026-09-26 kèm điều kiện màn xin đồng ý).
 *
 * Tầng này chỉ **lọc thô** và **cất**: gói ∈ danh sách trắng → không OTP → có mẫu
 * "± chữ số" → nối MỘT dòng JSON vào `filesDir/bien_dong_cho.jsonl` rồi cập nhật
 * một thông báo tóm tắt *không số*. Mọi phép **đọc** (số tiền, chiều, giờ, mã GD)
 * nằm ở Dart (`doc_tin_bien_dong.dart`) — một định nghĩa của "số tiền trong tin".
 *
 * Không tự tạo giao dịch. Không gửi gì ra ngoài. Không `READ_SMS`. Không log nội
 * dung tin — trừ chế độ **thu mẫu** chỉ sống ở bản debug (xem [thuMau]).
 *
 * `filesDir` ở đây ↔ `getApplicationSupportDirectory()` phía Dart (khác
 * `getApplicationDocumentsDirectory()` = `app_flutter/` mà hàng chờ B5a dùng).
 */
class BienDongListenerService : NotificationListenerService() {

    companion object {
        /**
         * Tên gói → tên nguồn hiển thị (đúng chữ của `kNguon*` phía Dart). Phải
         * khớp TỪNG CẶP với `kNguonTheoGoi` ở `doc_tin_bien_dong.dart` —
         * `bien_dong_noi_day_test.dart` đọc chính tệp này để so.
         *
         * ⚠️ CHỈ gói đã ĐO trên máy thật (Task 1 D1) — spec §2 cấm đoán, kể cả với
         * gói "ai cũng biết": app Tin nhắn của Realme / OnePlus / Samsung / Google
         * mỗi hãng một gói. Ba gói dưới đo trên OnePlus 13R 2026-09-30 bằng tin
         * biến động thật. Vietcombank, Techcombank, BIDV, Tin nhắn: chưa có dòng
         * nào → chưa vào.
         */
        val DANH_SACH_TRANG: Map<String, String> = mapOf(
            "com.mbmobile" to "MB Bank",
            "com.mservice.momotransfer" to "MoMo",
            "vn.com.vng.zalopay" to "ZaloPay",
        )

        const val TEP_HANG_CHO = "bien_dong_cho.jsonl"

        /** `SharedPreferences` của riêng tầng này; Dart ghi cờ qua kênh `datBat`. */
        const val TEN_PREFS = "bien_dong"
        const val KHOA_BAT = "bat"

        const val KENH_TOM_TAT = "flowmoney_bien_dong"
        const val ID_TOM_TAT = 20260930

        /** Extra trên Intent mở `MainActivity` từ thông báo tóm tắt; Dart hỏi qua `moTuThongBao`. */
        const val EXTRA_MO_TU_TOM_TAT = "bien_dong"

        private const val TAG_THU = "BienDongThu"

        /** Cùng chuỗi với `_otp` của `doc_tin_bien_dong.dart` — lớp lọc thứ nhất, trước khi ghi đĩa. */
        private val OTP = Regex("otp|mã xác thực|ma xac thuc", RegexOption.IGNORE_CASE)

        /**
         * Chỉ là bộ LỌC ("tin có mang một số tiền"), không trích gì: số kèm dấu ±
         * (tin ngân hàng) HOẶC số kèm đơn vị đ / ₫ / VND — tin MoMo, ZaloPay KHÔNG
         * có dấu ± (đo 2026-09-30); lọc chỉ theo ± là bỏ mọi tin của hai ví. Và
         * `VND` được chen giữa dấu và số: Techcombank viết `+ VND 208,080`
         * (`Classify.md` §4.3 mẫu 5) — bản đầu đòi chữ số ngay sau dấu nên bỏ
         * mọi tin Techcombank, `bien_dong_noi_day_test` bắt được.
         */
        private val CO_SO_TIEN = Regex("[+-]\\s?(vnd\\s?)?\\d[\\d.,]*|\\d[\\d.,]*\\s?(đ|₫|vnd)", RegexOption.IGNORE_CASE)

        fun bat(context: Context): Boolean =
            context.getSharedPreferences(TEN_PREFS, Context.MODE_PRIVATE).getBoolean(KHOA_BAT, false)

        fun datBat(context: Context, bat: Boolean) {
            context.getSharedPreferences(TEN_PREFS, Context.MODE_PRIVATE).edit().putBoolean(KHOA_BAT, bat).apply()
        }

        fun huyTomTat(context: Context) {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ID_TOM_TAT)
        }
    }

    /**
     * Chế độ thu mẫu (Task 1 D1): bản **debug** in `gói | tiêu đề | nội dung` của
     * MỌI thông báo ra logcat tag `BienDongThu`, để người dùng tự chép mẫu tin
     * ngân hàng (che số tài khoản, tên, mã GD) và tên gói thật. Bản release không
     * bao giờ vào nhánh này — `FLAG_DEBUGGABLE` do hệ thống đặt theo bản build,
     * không phải cờ mã có thể bật nhầm.
     */
    private val thuMau: Boolean
        get() = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            if (thuMau) thuMau(sbn)
            if (!bat(this)) return
            val goi = sbn.packageName
            // Ngoài danh sách trắng → thôi ngay, KHÔNG đọc extras (spec §2).
            if (!DANH_SACH_TRANG.containsKey(goi)) return
            // Bản tóm tắt nhóm của Android lặp lại nội dung các thông báo con.
            if ((sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return

            val extras = sbn.notification.extras
            val tieuDe = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val noiDung = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""
            val chu = "$tieuDe $noiDung"
            if (OTP.containsMatchIn(chu)) return
            if (!CO_SO_TIEN.containsMatchIn(chu)) return

            val dong = JSONObject()
                .put("goi", goi)
                .put("tieuDe", tieuDe)
                .put("noiDung", noiDung)
                .put("luc", sbn.postTime)
                .put("khoa", sbn.key)
                .toString()
            val tep = File(filesDir, TEP_HANG_CHO)
            tep.appendText(dong + "\n")
            baoTomTat(tep.readLines().count { it.isNotBlank() })
        } catch (_: Exception) {
            // Nuốt có chủ ý: một tin hỏng không được làm dịch vụ hệ thống văng.
        }
    }

    private fun thuMau(sbn: StatusBarNotification) {
        val e = sbn.notification.extras
        val tieuDe = e.getCharSequence(Notification.EXTRA_TITLE)
        val noiDung = e.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: e.getCharSequence(Notification.EXTRA_TEXT)
        Log.d(TAG_THU, "${sbn.packageName} | $tieuDe | $noiDung")
    }

    /**
     * MỘT thông báo id cố định, nội dung không số tiền, không tên người gửi —
     * "Có N biến động số dư mới — chạm để ghi". Chạm mở `MainActivity` kèm extra
     * [EXTRA_MO_TU_TOM_TAT]; Dart nhập hàng chờ ở `NotificationScanner.start`
     * / `resumed` rồi gọi [huyTomTat].
     */
    private fun baoTomTat(soDong: Int) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(KENH_TOM_TAT, "Biến động số dư", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val mo = Intent(this, MainActivity::class.java).apply {
            putExtra(EXTRA_MO_TU_TOM_TAT, true)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        var co = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) co = co or PendingIntent.FLAG_IMMUTABLE
        val pi = PendingIntent.getActivity(this, ID_TOM_TAT, mo, co)

        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, KENH_TOM_TAT)
        else Notification.Builder(this)
        val tb = b.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("FlowMoney")
            .setContentText("Có $soDong biến động số dư mới — chạm để ghi")
            .setContentIntent(pi)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .build()
        nm.notify(ID_TOM_TAT, tb)
    }
}
