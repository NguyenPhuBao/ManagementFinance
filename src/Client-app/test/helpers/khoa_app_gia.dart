/// Bản giả cho test khoá ứng dụng (Task 6–11).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/khoa_app/data/datasources/kenh_sinh_trac.dart';
import 'package:flowmoney/features/khoa_app/domain/bam_ma_pin.dart';

/// Kênh giả: "mã hoá" = đảo byte (đủ để kiểm luồng); [loiMo] / [loiBat] ép mã lỗi; [may] = trạng thái máy.
class KenhGia implements KenhSinhTrac {
  LoiSinhTrac? loiBat;
  LoiSinhTrac? loiMo;
  int soLanXoa = 0;
  Uint8List? traVeKhac;
  TrangThaiSinhTrac may = const TrangThaiSinhTrac(hoTro: true, daDangKy: true);

  @override
  Future<TrangThaiSinhTrac> trangThai() async => may;
  @override
  Future<KetQuaBatVanTay> bat(int idaccount, Uint8List biMat) async => loiBat != null
      ? KetQuaBatVanTay.loi(loiBat!)
      : KetQuaBatVanTay.thanhCong(banMa: base64Encode(biMat.reversed.toList()), iv: 'aXY=');
  @override
  Future<KetQuaMoVanTay> mo(int idaccount, {required String banMa, required String iv}) async => loiMo != null
      ? KetQuaMoVanTay.loi(loiMo!)
      : KetQuaMoVanTay.thanhCong(traVeKhac ?? Uint8List.fromList(base64Decode(banMa).reversed.toList()));
  @override
  Future<void> xoaHet() async => soLanXoa++;
}

/// Băm 1 vòng — test không chờ PBKDF2 30.000 vòng, và không qua isolate (FakeAsync của widget test không chạy I/O).
Future<String> bamNhanh(String pin, List<int> salt, int soVong) async => bamMaPin(pin, salt, 1);

/// Chấm PIN theo loại (`day` / `rong`): khoá mỗi chấm mang chỉ số nên tìm theo tiền tố.
Finder chamPin(String loai) => find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('cham-$loai-'));
