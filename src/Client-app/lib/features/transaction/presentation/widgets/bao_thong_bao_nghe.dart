// lib/features/transaction/presentation/widgets/bao_thong_bao_nghe.dart
/// Báo một [ThongBaoNghe] của micro bằng toast — MỘT chỗ cho ô Nhập nhanh (màn Thêm giao dịch) và thanh nhập Trợ lý AI
/// (2026-11-20; dời nguyên văn từ `_baoNghe` của `add_transaction_page.dart`).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../data/nguon_giong_noi.dart';
import '../../domain/chon_loi_nghe.dart';

/// [moCaiDatAi]: nút *Cài đặt AI* khi không có lối nghe nào (chỗ gọi tự điều hướng, nhớ kiểm `mounted`).
void baoThongBaoNghe(ThongBaoNghe t, {NguonGiongNoi? nguon, required VoidCallback moCaiDatAi}) {
  final hanhDong = switch (t) {
    ThongBaoNghe.biChanQuyen when nguon != null =>
      HanhDongToast('Mở cài đặt', () => unawaited(nguon.micro.moCaiDat())),
    ThongBaoNghe.khongCoLoi => HanhDongToast('Cài đặt AI', moCaiDatAi),
    _ => null,
  };
  // Thông báo hứa "bấm micro nói lại bằng AI trên máy" (kThuGemmaLuotSau) và "không nghe rõ" là thông tin, không lỗi.
  final thongTin = kThuGemmaLuotSau.contains(t) || t == ThongBaoNghe.khongNgheRo;
  baoNhanh(cauThongBaoNghe(t), loai: thongTin ? LoaiThongBao.thongTin : LoaiThongBao.loi, hanhDong: hanhDong);
}
