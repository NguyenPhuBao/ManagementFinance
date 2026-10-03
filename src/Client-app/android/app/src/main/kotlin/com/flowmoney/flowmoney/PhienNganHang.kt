package com.flowmoney.flowmoney

import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Nhắc ghi sau khi dùng app ngân hàng (spec `docs/superpowers/specs/2026-10-03-nhac-ghi-sau-app-ngan-hang-design.md`).
 *
 * Tầng này đọc `UsageStatsManager` (quyền *Truy cập dữ liệu sử dụng*, Android 10+), dựng phiên dùng app ngân hàng
 * và bắn / gỡ MỘT thông báo im lặng. **Không chạm SQLite**: bằng chứng nó thấy chỉ là hai tệp hàng chờ (tin D1, biên
 * lai) và việc FlowMoney đã được mở sau phiên — khi ấy để lượt nhập Dart (`NhapPhienNganHang`) xét đầy đủ.
 *
 * Gọi từ [NhacGhiWorker] (định kỳ 15 phút) và từ `BienDongListenerService` (mỗi thông báo, cách nhau ≥ 60 giây).
 * Không log tên app nào; bản debug chỉ log SỐ ĐẾM (tag [TAG]).
 */
object PhienNganHang {
    // Khớp TAY với `lib/core/notification/phien_ngan_hang.dart` — `phien_ngan_hang_noi_day_test.dart` so.
    const val GOP_PHIEN_MS = 180_000L
    const val TOI_THIEU_TREN_MAN_MS = 20_000L
    const val TRUOC_PHIEN_MS = 120_000L
    const val SAU_PHIEN_TIN_MS = 600_000L

    /** Phần nền chỉ lùi 1 ngày — phần cũ hơn để lượt nhập Dart (7 ngày) xét. */
    private const val LUI_NEN_MS = 86_400_000L

    /** Dịch vụ nghe thông báo gọi tới đây với MỌI thông báo của mọi app — hai lượt kiểm cách nhau ít nhất 60 giây. */
    private const val GIAN_KIEM_MS = 60_000L

    const val KENH = "flowmoney_nhac_ghi"
    const val ID_NHAC = 20261003
    const val TEN_WORK = "nhac_ghi"
    const val ACTION_KHONG_CO = "com.flowmoney.flowmoney.KHONG_CO_GIAO_DICH"

    // Cùng tệp SharedPreferences với cờ D1 và `co_phien`.
    private const val KHOA_BAT = "nhac_bat"
    private const val KHOA_DA_XET_DEN = "nhac_da_xet_den"
    private const val KHOA_BO_DEN = "nhac_bo_den"
    private const val KHOA_DA_BAO_DEN = "nhac_da_bao_den"
    private const val KHOA_NGUON_DANG_BAO = "nhac_nguon_dang_bao"
    private const val KHOA_KIEM_LUC = "nhac_kiem_luc"

    private const val TAG = "NhacGhi"

    data class SuKien(val goi: String, val lop: String, val vao: Boolean, val luc: Long)
    data class Phien(val goi: String, val batDau: Long, val ketThuc: Long, val trenMan: Long, val dangMo: Boolean)

    private val luongNen = Executors.newSingleThreadExecutor()

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(BienDongListenerService.TEN_PREFS, Context.MODE_PRIVATE)

    private fun debug(ctx: Context) = (ctx.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    fun coQuyen(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        return if (mode == AppOpsManager.MODE_DEFAULT) {
            ctx.checkCallingOrSelfPermission(Manifest.permission.PACKAGE_USAGE_STATS) == PackageManager.PERMISSION_GRANTED
        } else {
            mode == AppOpsManager.MODE_ALLOWED
        }
    }

    /** Trang riêng của app nếu máy hỗ trợ (`package:`), không thì danh sách *Truy cập dữ liệu sử dụng*. */
    fun moCaiDat(act: Activity) {
        val goc = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            act.startActivity(Intent(goc).setData(Uri.fromParts("package", act.packageName, null)))
        } catch (_: ActivityNotFoundException) {
            act.startActivity(goc)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun suKien(ctx: Context, tu: Long, den: Long, goi: Set<String>): List<SuKien> {
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val ds = usm.queryEvents(tu, den) ?: return emptyList()
        val e = UsageEvents.Event()
        val ra = ArrayList<SuKien>()
        while (ds.hasNextEvent()) {
            ds.getNextEvent(e)
            val g = e.packageName ?: continue
            if (g !in goi) continue
            val vao = when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> true
                UsageEvents.Event.ACTIVITY_PAUSED -> false
                else -> continue
            }
            ra.add(SuKien(g, e.className ?: "", vao, e.timeStamp))
        }
        return ra
    }

    /** Kênh `suKien` — CHỈ gói theo dõi: lọc trước khi trả, không tên app nào khác rời khỏi tầng này. */
    fun suKienChoDart(ctx: Context, tu: Long): List<Map<String, Any>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return emptyList()
        if (!coQuyen(ctx)) return emptyList()
        return suKien(ctx, tu, System.currentTimeMillis(), BienDongListenerService.DANH_SACH_TRANG.keys).map {
            mapOf("goi" to it.goi, "lop" to it.lop, "loai" to if (it.vao) "vao" else "ra", "luc" to it.luc)
        }
    }

    /** Khớp TAY với `phienTuSuKien` (Dart) — theo LỚP, gộp khe ≤ [GOP_PHIEN_MS], bỏ sự kiện sau [bayGio] và rời lẻ. */
    fun dungPhien(ds: List<SuKien>, bayGio: Long): List<Phien> {
        val ra = ArrayList<Phien>()
        val theoGoi = ds.withIndex()
            .filter { it.value.luc <= bayGio }
            .sortedWith(compareBy({ it.value.luc }, { it.index }))
            .map { it.value }
            .groupBy { it.goi }
        for ((goi, cuaGoi) in theoGoi) {
            val khoang = ArrayList<Pair<Long, Long?>>()
            val tren = HashSet<String>()
            var moTu: Long? = null
            for (e in cuaGoi) {
                if (e.vao) {
                    if (tren.isEmpty()) moTu = e.luc
                    tren.add(e.lop)
                } else if (tren.remove(e.lop) && tren.isEmpty()) {
                    val bd = moTu
                    if (bd != null) {
                        khoang.add(Pair(bd, e.luc))
                        moTu = null
                    }
                }
            }
            moTu?.let { khoang.add(Pair(it, null)) }
            var hien: Phien? = null
            for ((bd, kt) in khoang) {
                val ket = kt ?: bayGio
                val dai = ket - bd
                val h = hien
                hien = if (h != null && !h.dangMo && bd - h.ketThuc <= GOP_PHIEN_MS) {
                    h.copy(ketThuc = ket, trenMan = h.trenMan + dai, dangMo = kt == null)
                } else {
                    if (h != null) ra.add(h)
                    Phien(goi, bd, ket, dai, kt == null)
                }
            }
            hien?.let { ra.add(it) }
        }
        return ra.sortedBy { it.batDau }
    }

    fun boDen(ctx: Context): Long? = prefs(ctx).getLong(KHOA_BO_DEN, 0L).takeIf { it > 0 }

    fun datBat(ctx: Context, bat: Boolean, daXetDen: Long) {
        val ed = prefs(ctx).edit().putBoolean(KHOA_BAT, bat)
        if (daXetDen > 0) ed.putLong(KHOA_DA_XET_DEN, daXetDen)
        ed.apply()
        val wm = WorkManager.getInstance(ctx)
        if (bat) {
            wm.enqueueUniquePeriodicWork(
                TEN_WORK,
                ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<NhacGhiWorker>(15, TimeUnit.MINUTES).build(),
            )
        } else {
            wm.cancelUniqueWork(TEN_WORK)
            huyNhac(ctx)
        }
    }

    fun huyNhac(ctx: Context) {
        prefs(ctx).edit().remove(KHOA_NGUON_DANG_BAO).apply()
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ID_NHAC)
    }

    /** Nút *Không có giao dịch*: mọi phiên đang nằm trong thông báo không bao giờ thành dòng. */
    fun boQua(ctx: Context) {
        val p = prefs(ctx)
        p.edit().putLong(KHOA_BO_DEN, p.getLong(KHOA_DA_BAO_DEN, 0L)).apply()
        huyNhac(ctx)
    }

    /** Từ dịch vụ nghe thông báo: rẻ, không chặn luồng chính, giãn [GIAN_KIEM_MS]. */
    fun kiemNen(context: Context) {
        val ctx = context.applicationContext
        val p = prefs(ctx)
        if (!p.getBoolean(KHOA_BAT, false)) return
        if (System.currentTimeMillis() - p.getLong(KHOA_KIEM_LUC, 0L) < GIAN_KIEM_MS) return
        luongNen.execute {
            try {
                kiem(ctx, "nls")
            } catch (_: Exception) {
                // Nuốt có chủ ý: dịch vụ hệ thống không được văng vì một lượt kiểm.
            }
        }
    }

    @Synchronized
    fun kiem(ctx: Context, lyDo: String) {
        val p = prefs(ctx)
        val bayGio = System.currentTimeMillis()
        val bat = p.getBoolean(KHOA_BAT, false)
        val coPhien = NhanBienLaiActivity.coPhien(ctx)
        val quyen = coQuyen(ctx)
        if (debug(ctx)) Log.d(TAG, "kiem=$lyDo bat=$bat coPhien=$coPhien quyen=$quyen")
        if (!bat || !coPhien) return
        p.edit().putLong(KHOA_KIEM_LUC, bayGio).apply()
        if (!quyen) {
            // Phiên lúc không có quyền không bao giờ được nhắc — cấp lại quyền không đổ một tràng phiên cũ (spec §4.4).
            p.edit().putLong(KHOA_DA_XET_DEN, bayGio).apply()
            return
        }
        // `coQuyen` đã trả false dưới Android 10; tách riêng để lint thấy `suKien` (@RequiresApi Q) được gác.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val tu = maxOf(
            maxOf(p.getLong(KHOA_DA_XET_DEN, 0L), p.getLong(KHOA_BO_DEN, 0L)),
            maxOf(p.getLong(KHOA_DA_BAO_DEN, 0L), bayGio - LUI_NEN_MS),
        )
        val nganHang = BienDongListenerService.DANH_SACH_TRANG.keys
        val ev = suKien(ctx, tu, bayGio, nganHang + ctx.packageName)
        val moApp = ev.filter { it.goi == ctx.packageName && it.vao }.map { it.luc }
        val phien = dungPhien(ev.filter { it.goi in nganHang }, bayGio)
        val nhac = phien.filter { ph ->
            !ph.dangMo && bayGio - ph.ketThuc >= GOP_PHIEN_MS && ph.batDau > tu &&
                ph.trenMan >= TOI_THIEU_TREN_MAN_MS &&
                // Đã mở FlowMoney sau khi phiên bắt đầu → lượt nhập Dart xét (nó thấy cả sổ giao dịch).
                moApp.none { it >= ph.batDau } &&
                !coBangChung(ctx, ph)
        }
        if (debug(ctx)) Log.d(TAG, "kiem=$lyDo su_kien=${ev.size} phien=${phien.size} nhac=${nhac.size}")
        if (nhac.isEmpty()) return
        val nguon = (dangBao(p) + nhac.mapNotNull { BienDongListenerService.DANH_SACH_TRANG[it.goi] }).distinct()
        p.edit()
            .putLong(KHOA_DA_BAO_DEN, nhac.maxOf { it.ketThuc })
            .putString(KHOA_NGUON_DANG_BAO, nguon.joinToString("|"))
            .apply()
        bao(ctx, nguon)
    }

    private fun dangBao(p: SharedPreferences): List<String> =
        p.getString(KHOA_NGUON_DANG_BAO, null)?.split("|")?.filter { it.isNotEmpty() } ?: emptyList()

    /** Tin D1 hoặc biên lai CÙNG gói đang nằm trong hàng chờ, trong [mở − 2 phút, rời + 10 phút]. */
    private fun coBangChung(ctx: Context, ph: Phien): Boolean {
        val tu = ph.batDau - TRUOC_PHIEN_MS
        val den = ph.ketThuc + SAU_PHIEN_TIN_MS
        for (ten in listOf(BienDongListenerService.TEP_HANG_CHO, NhanBienLaiActivity.TEP_HANG_CHO)) {
            val f = File(ctx.filesDir, ten)
            if (!f.exists()) continue
            for (dong in f.readLines()) {
                try {
                    val j = JSONObject(dong)
                    if (j.optString("goi") == ph.goi && j.optLong("luc") in tu..den) return true
                } catch (_: Exception) {
                    // Dòng hỏng thì bỏ.
                }
            }
        }
        return false
    }

    private fun bao(ctx: Context, nguon: List<String>) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(KENH, "Nhắc ghi sau khi dùng app ngân hàng", NotificationManager.IMPORTANCE_LOW)
            )
        }
        var co = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) co = co or PendingIntent.FLAG_IMMUTABLE
        // Chạm → đúng đường của tóm tắt D1: MainActivity + extra → `MoTuTomTatBienDong` mở danh sách Biến động.
        val mo = Intent(ctx, MainActivity::class.java).apply {
            putExtra(BienDongListenerService.EXTRA_MO_TU_TOM_TAT, true)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pi = PendingIntent.getActivity(ctx, ID_NHAC, mo, co)
        val khong = Intent(ctx, NhacGhiReceiver::class.java).setAction(ACTION_KHONG_CO)
        val piKhong = PendingIntent.getBroadcast(ctx, ID_NHAC, khong, co)

        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(ctx, KENH)
        else Notification.Builder(ctx)
        @Suppress("DEPRECATION")
        val tb = b.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("FlowMoney")
            .setContentText("Vừa dùng ${nguon.joinToString(", ")} — có giao dịch cần ghi?")
            .setContentIntent(pi)
            .addAction(Notification.Action.Builder(0, "Không có giao dịch", piKhong).build())
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .build()
        nm.notify(ID_NHAC, tb)
        if (debug(ctx)) Log.d(TAG, "bao so_nguon=${nguon.size}")
    }
}
