/// Dựng `GoiCubit` mang một `TrangThaiGoi` cố định cho widget test (B1, 2026-10-27) — thay bản chép tay `_ApiIm` +
/// `GoiRepository` + `emit` ở từng tệp. Tự dọn bằng `addTearDown`: gọi TRONG thân ca (hoặc `setUp`).
library;

import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/models/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/data/repositories/goi_repository.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class ApiGoiIm implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) => throw UnimplementedError();
}

/// `GoiCubit` phát đúng [t].
GoiCubit goiTheo(TrangThaiGoi t, {DateTime? now}) {
  DateTime Function()? clock;
  if (now != null) {
    final n = now;
    clock = () => n;
  }
  final repo = GoiRepository(api: ApiGoiIm(), kho: InMemoryGoiStore(), clock: clock);
  final cubit = GoiCubit(repo, clock: clock)..emit(t);
  addTearDown(() async {
    await cubit.close();
    await repo.dispose();
  });
  return cubit;
}

/// Basic mang bảng [quyen] (và cột Premium [quyenPremium] nếu có).
GoiCubit goiBasic(Map<String, bool> quyen, {Map<String, bool> quyenPremium = const {}, DateTime? now}) => goiTheo(
    TrangThaiGoi(loai: LoaiGoi.basic, nhanLuc: now ?? DateTime.now(), quyenTinhNang: quyen, quyenPremium: quyenPremium),
    now: now);

/// Premium còn hạn 30 ngày mang bảng [quyen] — `false` ở đây là *tạm ngừng* (B1).
GoiCubit goiPremium(Map<String, bool> quyen, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return goiTheo(
      TrangThaiGoi(
          loai: LoaiGoi.premium, hetHan: n.add(const Duration(days: 30)), nhanLuc: n, quyenTinhNang: quyen),
      now: n);
}
