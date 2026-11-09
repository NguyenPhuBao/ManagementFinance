/// Dịch vụ góp / rút giả cho test của mảng gia đình: ghi lại lời gọi, `docCap` đọc từ cặp tiêm được, lỗi ném theo lệnh.
library;

import 'dart:async';

import 'package:flowmoney/features/household/application/gop_quy_service.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';

typedef LoiGopGia = ({
  int idNha,
  int idaccount,
  String viChungId,
  String tenViChung,
  double soTien,
  String? viRiengId,
  DateTime ngay,
  String ghiChu
});

class GopQuyGia implements GopQuyService {
  GopQuyGia({this.rieng, this.nha});

  /// Cặp trả về cho `docCap`.
  TransactionEntity? rieng, nha;

  final gop_ = <LoiGopGia>[];
  final rut_ = <LoiGopGia>[];
  final sua_ = <({String maCap, double soTien, DateTime ngay, String ghiChu})>[];
  final docCap_ = <String>[];

  /// Ném ở lệnh tương ứng (nếu khác `null`); `suaTra` là giá trị `sua` trả về.
  Object? loi;
  bool suaTra = true;

  /// Nếu khác `null`, `gop` / `rut` chờ nó trước khi trả (ca chạm đôi).
  Completer<void>? cho;

  Future<String> _ghi(List<LoiGopGia> ds, LoiGopGia l) async {
    ds.add(l);
    final c = cho;
    if (c != null) await c.future;
    final e = loi;
    if (e != null) throw e;
    return 'ma-cap-moi';
  }

  @override
  Future<String> gop({
    required int idNha,
    required int idaccount,
    required String viChungId,
    required String tenViChung,
    required double soTien,
    String? viRiengId,
    required DateTime ngay,
    String ghiChu = '',
  }) =>
      _ghi(gop_, (
        idNha: idNha,
        idaccount: idaccount,
        viChungId: viChungId,
        tenViChung: tenViChung,
        soTien: soTien,
        viRiengId: viRiengId,
        ngay: ngay,
        ghiChu: ghiChu
      ));

  @override
  Future<String> rut({
    required int idNha,
    required int idaccount,
    required String viChungId,
    required String tenViChung,
    required double soTien,
    required String viRiengId,
    required DateTime ngay,
    String ghiChu = '',
  }) =>
      _ghi(rut_, (
        idNha: idNha,
        idaccount: idaccount,
        viChungId: viChungId,
        tenViChung: tenViChung,
        soTien: soTien,
        viRiengId: viRiengId,
        ngay: ngay,
        ghiChu: ghiChu
      ));

  @override
  Future<bool> sua({required String maCap, required double soTien, required DateTime ngay, required String ghiChu}) async {
    sua_.add((maCap: maCap, soTien: soTien, ngay: ngay, ghiChu: ghiChu));
    final e = loi;
    if (e != null) throw e;
    return suaTra;
  }

  @override
  Future<({TransactionEntity? rieng, TransactionEntity? nha})> docCap(String maCap) async {
    docCap_.add(maCap);
    return (rieng: rieng, nha: nha);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
