// test/helpers/them_giao_dich_nguon_gia.dart
/// Nguồn giả của `ThemGiaoDichCubit` — test Cubit giả NGUỒN, không giả từng store. Mọi hàm ghi lại lời gọi.
library;

import 'dart:async';
import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';

import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart' show PhanHoiGoiY;
import 'package:flowmoney/features/transaction/data/doc_cau_bang_ai.dart';
import 'package:flowmoney/features/transaction/data/them_giao_dich_nguon.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_mon_hang.dart';

class NguonThemGiaoDichGia implements ThemGiaoDichNguon {
  NguonThemGiaoDichGia({
    this.vi = const [],
    LichSuHoc? lichSu,
    this.danhMuc = const [],
    this.bangTuKhoa = const {},
    this.phanHoi = const [],
    this.viNho = const {},
    this.hangCho = const [],
    this.so = const [],
    this.docAiGia,
    this.duongDan,
    this.mon = const [],
    this.nganSach,
  }) : lichSu = lichSu ?? (viHayDung: const {}, boPhanLoai: null, boSoTien: null, mauDeXuat: null);

  List<WalletEntity> vi;
  LichSuHoc lichSu;
  List<CategoryEntity> danhMuc;
  Map<String, List<String>> bangTuKhoa;
  List<PhanHoiGoiY> phanHoi;

  /// Khoá `'<nguon>|<duoi>'` (duoi rỗng khi null) → id ví.
  Map<String, String> viNho;
  List<DienSanBienDong> hangCho;
  List<KhoanSo> so;
  DocCauBangAi? docAiGia;
  String? duongDan;
  List<MonHang> mon;
  Future<BudgetView?> Function(int idaccount, String categoryId)? nganSach;

  /// Khác `null` → [danhMucChonDuoc] treo tới khi test `complete` nó (ca "kết quả về muộn bị bỏ").
  Completer<List<CategoryEntity>>? choDanhMuc;

  final phanHoiDaGhi = <({String goiY, String ketQua, String? chon})>[];

  /// Dấu "danh mục do AI chọn, lưu nguyên" (người dùng chốt 2026-10-16).
  final aiDoanDaDanhDau = <({String tx, String dm})>[];
  final aiDoanDaGo = <String>[];
  final viDaNho = <String>[];
  final hangDaXoa = <String>[];
  final anhBienLaiDaXoa = <String?>[];
  final anhQuetDaXoa = <String?>[];
  final tuKhoaDaLuu = <String, List<String>>{};
  int soLanDocViTheoNguon = 0;

  @override
  FutureOr<List<WalletEntity>> napViDangDung(int? idaccount) => idaccount == null ? const [] : vi;
  @override
  FutureOr<LichSuHoc> napLichSu(int? idaccount, {String? dangSua}) => lichSu;
  @override
  Future<List<PhanHoiGoiY>?> docPhanHoi(int idaccount) async => phanHoi;
  @override
  void ghiPhanHoi({required int idaccount, required CategorySuggestion goiY, required String ketQua, String? chon}) =>
      phanHoiDaGhi.add((goiY: goiY.categoryId, ketQua: ketQua, chon: chon));

  @override
  void danhDauDanhMucAi({required int idaccount, required String transactionId, required String categoryId}) =>
      aiDoanDaDanhDau.add((tx: transactionId, dm: categoryId));

  @override
  void goDanhDauDanhMucAi({required int idaccount, required String transactionId}) => aiDoanDaGo.add(transactionId);
  @override
  Future<List<CategoryEntity>> danhMucChonDuoc(int idaccount) => choDanhMuc?.future ?? Future.value(danhMuc);
  @override
  Future<Map<String, List<String>>> tuKhoa(int idaccount) async => bangTuKhoa;
  @override
  Future<(List<CategoryEntity>, Map<String, List<String>>)> napDanhMucVaTuKhoa(int? idaccount) async =>
      idaccount == null ? (const <CategoryEntity>[], const <String, List<String>>{}) : (danhMuc, bangTuKhoa);
  @override
  Future<void> luuTuKhoa({required int idaccount, required String categoryId, required List<String> tuKhoa}) async =>
      tuKhoaDaLuu[categoryId] = tuKhoa;
  @override
  DocCauBangAi? get docAi => docAiGia;
  @override
  Future<String?> viTheoNguon(int idaccount, String nguon, String? duoi) async {
    soLanDocViTheoNguon++;
    return viNho['$nguon|${duoi ?? ''}'];
  }

  @override
  Future<String?> viTheoNguonChung(int idaccount, String nguon) async {
    soLanDocViTheoNguon++;
    return null;
  }

  @override
  Future<void> nhoViTheoNguon(int idaccount, String nguon, String? duoi, String walletId) async =>
      viDaNho.add('$nguon|${duoi ?? ''}=$walletId');
  @override
  Future<List<DienSanBienDong>> hangBienDongCho(int idaccount) async => hangCho;
  @override
  Future<List<KhoanSo>> khoanTrongSo(int idaccount) async => so;
  @override
  Future<void> xoaHangBienDong(int idaccount, String khoa) async => hangDaXoa.add(khoa);
  @override
  Future<String?> duongDanAnh(DienSanBienDong d) async => duongDan;
  @override
  Future<List<MonHang>> docMonQuet(String anh) async => mon;
  @override
  Future<void> xoaAnhBienLai(String? anh) async => anhBienLaiDaXoa.add(anh);
  @override
  Future<void> xoaAnhQuet(String? anh) async => anhQuetDaXoa.add(anh);
  @override
  Future<BudgetView?> traNganSach(int idaccount, String categoryId) async => nganSach?.call(idaccount, categoryId);
}
