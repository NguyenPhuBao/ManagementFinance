package com.flowmoney.flowmoney

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

/** Đường nền định kỳ (15 phút) của nhắc ghi — xem [PhienNganHang]. Luôn `success`: lượt hỏng thì lượt sau thử lại. */
class NhacGhiWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        try {
            PhienNganHang.kiem(applicationContext, "worker")
        } catch (_: Exception) {
            // Nuốt có chủ ý.
        }
        return Result.success()
    }
}
