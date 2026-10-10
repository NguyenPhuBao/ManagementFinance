package com.flowmoney.flowmoney

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * Lượt nền của tự chuyển tiền — xem [TuChuyenTien]. Luôn `success`: lượt hỏng thì lượt định kỳ 6 giờ thử lại;
 * `retry` dễ thành vòng lặp tốn pin.
 */
class TuChuyenTienWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        try {
            // App đang mở: engine của app tự quét và tự hẹn lượt kế qua `henNen`.
            if (TuChuyenTien.quetTrongApp()) return Result.success()

            val (moc, coTuDong) = TuChuyenTien.chayHeadless(applicationContext)
            // Chính lượt một-lần đang chạy: REPLACE lên nó là WorkManager huỷ nó — nối lượt kế vào SAU nó.
            val chinhSach =
                if (tags.contains(TuChuyenTien.TEN_MOT_LAN)) ExistingWorkPolicy.APPEND_OR_REPLACE
                else ExistingWorkPolicy.REPLACE
            TuChuyenTien.henVoi(applicationContext, moc, coTuDong, chinhSach)
        } catch (_: InterruptedException) {
            // Bị huỷ — app vừa hẹn lại bằng REPLACE, tức app đang tự làm việc này.
        } catch (_: Exception) {
            // Nuốt có chủ ý.
        }
        return Result.success()
    }
}
