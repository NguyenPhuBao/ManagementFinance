package com.flowmoney.flowmoney

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Nút *Không có giao dịch* trên thông báo nhắc — chạy được cả khi FlowMoney đã bị đóng / đóng băng. */
class NhacGhiReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == PhienNganHang.ACTION_KHONG_CO) PhienNganHang.boQua(context)
    }
}
