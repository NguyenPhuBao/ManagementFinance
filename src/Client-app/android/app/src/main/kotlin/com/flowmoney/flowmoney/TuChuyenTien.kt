package com.flowmoney.flowmoney

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Tự chuyển tiền chạy nền — tự trả hoá đơn và trích mục tiêu khi app đóng
 * (spec `docs/superpowers/specs/2026-10-10-tu-chuyen-tien-chay-nen-design.md`).
 *
 * Kênh `flowmoney/tu_chuyen_tien` (engine của APP): Dart gọi `henNen` {moc, coTuDong}; Kotlin gọi `quetNgay`.
 * Kênh `flowmoney/tu_chuyen_tien_nen` (engine NỀN): Dart gọi `nenXong` {moc, coTuDong}.
 * `moc` là mili-giây epoch, 0 = không hẹn lượt một-lần.
 */
object TuChuyenTien {
    const val KENH = "flowmoney/tu_chuyen_tien"
    const val KENH_NEN = "flowmoney/tu_chuyen_tien_nen"
    const val ENTRYPOINT = "chayNenTuChuyenTien"
    const val TEN_MOT_LAN = "tu_chuyen_tien_mot_lan"
    const val TEN_DINH_KY = "tu_chuyen_tien_dinh_ky"
    private const val TAG = "TuChuyenTien"

    /** Engine của `MainActivity` khi app đang mở — worker giao việc cho nó thay vì mở kết nối SQLite thứ hai. */
    @Volatile private var engineApp: FlutterEngine? = null

    fun ganEngineApp(e: FlutterEngine?) {
        engineApp = e
    }

    /** Lệnh `henNen` từ engine của app — REPLACE: lượt một-lần đang chờ (nếu có) được thay bằng mốc mới. */
    fun hen(ctx: Context, mocMs: Long, coTuDong: Boolean) =
        henVoi(ctx, mocMs, coTuDong, ExistingWorkPolicy.REPLACE)

    /**
     * [chinhSach] — lượt một-lần đang chạy tự hẹn lượt kế phải dùng APPEND_OR_REPLACE: REPLACE lên chính công việc
     * đang chạy là WorkManager huỷ nó (luồng bị ngắt, engine bị huỷ khi Dart còn đồng bộ).
     */
    fun henVoi(ctx: Context, mocMs: Long, coTuDong: Boolean, chinhSach: ExistingWorkPolicy) {
        val wm = WorkManager.getInstance(ctx)
        if (mocMs > 0) {
            val tre = (mocMs - System.currentTimeMillis()).coerceAtLeast(0L)
            wm.enqueueUniqueWork(
                TEN_MOT_LAN,
                chinhSach,
                OneTimeWorkRequestBuilder<TuChuyenTienWorker>()
                    .setInitialDelay(tre, TimeUnit.MILLISECONDS)
                    .addTag(TEN_MOT_LAN)
                    .build(),
            )
        } else {
            wm.cancelUniqueWork(TEN_MOT_LAN)
        }
        if (coTuDong) {
            wm.enqueueUniquePeriodicWork(
                TEN_DINH_KY,
                ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<TuChuyenTienWorker>(6, TimeUnit.HOURS).build(),
            )
        } else {
            wm.cancelUniqueWork(TEN_DINH_KY)
        }
        Log.i(TAG, "Hẹn lượt nền: mốc $mocMs, định kỳ $coTuDong")
    }

    /** App đang mở: quét trong engine của app và CHỜ xong. `true` = đã giao cho app. */
    fun quetTrongApp(): Boolean {
        val e = engineApp ?: return false
        val xong = CountDownLatch(1)
        Handler(Looper.getMainLooper()).post {
            try {
                MethodChannel(e.dartExecutor.binaryMessenger, KENH).invokeMethod(
                    "quetNgay",
                    null,
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            xong.countDown()
                        }

                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                            xong.countDown()
                        }

                        override fun notImplemented() {
                            xong.countDown()
                        }
                    },
                )
            } catch (ex: Exception) {
                xong.countDown()
            }
        }
        xong.await(3, TimeUnit.MINUTES)
        Log.i(TAG, "quetNgay trong engine của app")
        return true
    }

    /** App đóng: dựng engine headless, chạy entrypoint nền, CHỜ `nenXong`. Trả (mốc ms, còn tự động). */
    fun chayHeadless(ctx: Context): Pair<Long, Boolean> {
        val xong = CountDownLatch(1)
        var moc = 0L
        var coTuDong = true
        var engine: FlutterEngine? = null
        val main = Handler(Looper.getMainLooper())
        main.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(ctx)
                loader.ensureInitializationComplete(ctx, null)
                // Hàm dựng tự đăng ký plugin (GeneratedPluginRegistrant): secure storage, local notifications,
                // connectivity, path_provider… Kênh riêng của MainActivity thì KHÔNG có ở đây — lượt nền không dùng.
                val e = FlutterEngine(ctx)
                MethodChannel(e.dartExecutor.binaryMessenger, KENH_NEN).setMethodCallHandler { call, r ->
                    if (call.method == "nenXong") {
                        moc = (call.argument<Number>("moc") ?: 0).toLong()
                        coTuDong = call.argument<Boolean>("coTuDong") ?: true
                        r.success(null)
                        xong.countDown()
                    } else {
                        r.notImplemented()
                    }
                }
                e.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
                )
                engine = e
            } catch (ex: Exception) {
                Log.e(TAG, "Không dựng được engine nền", ex)
                xong.countDown()
            }
        }
        xong.await(3, TimeUnit.MINUTES)
        main.post { engine?.destroy() }
        Log.i(TAG, "Lượt nền xong — mốc kế $moc, còn tự động $coTuDong")
        return Pair(moc, coTuDong)
    }
}
