/// Một PHIÊN hội thoại có tool — giao diện thuần + bản giả, đúng tiền lệ
/// `nguon_tai_nen.dart` (giao diện và `NguonTaiNenGia` cạnh nhau, bản thật ở
/// tệp riêng). Bản thật nằm trong `slm_runtime.dart`, tệp DUY NHẤT được import
/// `flutter_gemma` (test quét 16).
///
/// Một lượt sinh ([PhienCongCu.sinhLuot]) phát chữ và/hoặc lời gọi tool; lượt
/// **không** có lời gọi nào là câu trả lời cuối. Với Gemma 4 trên LiteRT-LM,
/// lượt gọi tool thường không phát chữ — gói nuốt JSON `{`-đầu và trả lời gọi
/// có cấu trúc ở cuối luồng (spec 4b mục 2).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;

sealed class SuKienLuot {
  const SuKienLuot();
}

class Chu extends SuKienLuot {
  final String token;
  const Chu(this.token);

  @override
  bool operator ==(Object other) => other is Chu && other.token == token;
  @override
  int get hashCode => token.hashCode;
  @override
  String toString() => 'Chu($token)';
}

class GoiCongCu extends SuKienLuot {
  final String ten;
  final Map<String, dynamic> args;
  const GoiCongCu(this.ten, this.args);

  @override
  bool operator ==(Object other) =>
      other is GoiCongCu && other.ten == ten && mapEquals(other.args, args);
  @override
  int get hashCode => Object.hash(ten, args.length);
  @override
  String toString() => 'GoiCongCu($ten $args)';
}

abstract class PhienCongCu {
  Stream<SuKienLuot> sinhLuot();

  Future<void> traKetQua(String ten, Map<String, dynamic> json);

  /// Dừng lượt đang sinh (engine native thôi giải mã). Không có lượt nào đang
  /// chạy thì im lặng.
  Future<void> huy();

  Future<void> dong();
}

/// Bản giả cho test: [kichBan] là danh sách LƯỢT, mỗi lượt một danh sách sự
/// kiện phát theo thứ tự. Hết kịch bản thì lượt rỗng (mô hình im lặng).
class PhienCongCuGia implements PhienCongCu {
  PhienCongCuGia(this.kichBan);

  final List<List<SuKienLuot>> kichBan;
  final List<(String, Map<String, dynamic>)> ketQuaDaNhan = [];
  int luotDaSinh = 0;
  int soLanHuy = 0;
  bool daDong = false;

  @override
  Stream<SuKienLuot> sinhLuot() {
    if (luotDaSinh >= kichBan.length) return const Stream.empty();
    return Stream.fromIterable(kichBan[luotDaSinh++]);
  }

  @override
  Future<void> traKetQua(String ten, Map<String, dynamic> json) async =>
      ketQuaDaNhan.add((ten, json));

  @override
  Future<void> huy() async => soLanHuy++;

  @override
  Future<void> dong() async => daDong = true;
}
