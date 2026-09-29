// C1 — gắn danh mục hàng loạt: chọn giao dịch chưa phân loại và đoán theo chiều tiền (spec
// `2026-09-28-c1-gan-danh-muc-hang-loat-design.md` §2).
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/domain/bill_note.dart';
import 'package:flowmoney/features/category/domain/gan_hang_loat.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/goal/domain/goal_history_direction.dart';
import 'package:flowmoney/features/wallet/domain/dieu_chinh_so_du.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

import '../presentation/category_test_fakes.dart';

var _dem = 0;

Transaction _gd(
  String note, {
  String type = 'chi',
  String? cat,
  DateTime? ngay,
  bool isDeleted = false,
  DateTime? deletedAt,
}) {
  final d = ngay ?? DateTime(2026, 9, 10);
  return Transaction(
    id: 'gd-${_dem++}',
    walletId: 'v1',
    idaccount: 10,
    categoryId: cat,
    amount: 50000,
    type: type,
    status: 'completed',
    provider: 'Manual',
    note: note,
    date: d,
    images: '',
    syncStatus: 'synced',
    syncRetryCount: 0,
    updatedAt: d,
    isDeleted: isDeleted,
    deletedAt: deletedAt,
  );
}

final _diChuyen = makeCategory(id: 'c-dc', name: 'Di chuyển');
final _anUong = makeCategory(id: 'c-an', name: 'Ăn uống');
final _luong = makeCategory(id: 'c-luong', name: 'Lương', classify: 'thu');
final _choVay = makeCategory(id: 'c-vay', name: 'Cho vay', classify: 'vay_no');
final _chonDuoc = [_diChuyen, _anUong, _luong, _choVay];

List<MauGhiChu> _mau(String ghiChu, String cat, int so) => [
      for (var i = 0; i < so; i++)
        MauGhiChu(categoryId: cat, amTiet: amTietCua(ghiChu), ngay: DateTime(2026, 8, 1 + i)),
    ];

void main() {
  group('xetGan — điều kiện "xét" duy nhất', () {
    test('khoản chi trơn không danh mục thì xét', () {
      expect(xetGan(_gd('grab')), isTrue);
      expect(xetGan(_gd('ban tra no', type: 'thu')), isTrue);
    });

    test('ghi chú rỗng vẫn xét — người dùng chọn tay được trên cùng màn', () {
      expect(xetGan(_gd('')), isTrue);
    });

    test('khoản đã có danh mục thì không', () {
      expect(xetGan(_gd('grab', cat: 'c-dc')), isFalse);
    });

    test('khoản chuyển thì không', () {
      expect(xetGan(_gd('chuyen', type: 'transfer')), isFalse);
    });

    test('khoản do máy sinh thì không — cùng nhận dạng với B1 (laGhiChuMay)', () {
      for (final note in [
        '$tienToDieuChinh (đối soát)',
        tienToMoSo,
        '${kGhiChuNapMucTieu}MuaXe',
        '${kGhiChuRutMucTieu}MuaXe',
        '${kGhiChuTraHoaDon}Netflix',
      ]) {
        expect(xetGan(_gd(note)), isFalse,
            reason: '"$note" do máy ghi và cố ý không có danh mục — gắn nó là đổi một khoản sửa sổ thành chi tiêu');
      }
    });

    test('khoản đã xoá thì không, theo cả hai cột xoá', () {
      expect(xetGan(_gd('grab', isDeleted: true)), isFalse);
      expect(xetGan(_gd('grab', deletedAt: DateTime(2026, 9, 11))), isFalse);
    });
  });

  test('demChuaGan đếm đúng tập mà xetGan chọn', () {
    final ds = [
      _gd('grab'),
      _gd('com trua'),
      _gd('grab', cat: 'c-dc'),
      _gd('chuyen', type: 'transfer'),
      _gd(tienToMoSo, type: 'thu'),
      _gd('grab', isDeleted: true),
    ];
    expect(demChuaGan(ds), 2);
    expect(demChuaGan(ds), ds.where(xetGan).length,
        reason: 'thẻ ở Sổ giao dịch và màn duyệt phải nói cùng một con số');
  });

  group('hopLeTheoChieu', () {
    test('khoản chi → danh mục chi và vay/nợ', () {
      expect(hopLeTheoChieu('chi', _chonDuoc), {'c-dc', 'c-an', 'c-vay'});
    });

    test('khoản thu → danh mục thu và vay/nợ', () {
      expect(hopLeTheoChieu('thu', _chonDuoc), {'c-luong', 'c-vay'});
    });

    test('bỏ danh mục đã xoá và nhóm', () {
      final xoa = makeCategory(id: 'c-xoa', name: 'Cũ').copyWith(isDeleted: true);
      final nhom = makeCategory(id: 'c-nhom', name: 'Nhóm', isGroup: true);
      expect(hopLeTheoChieu('chi', [..._chonDuoc, xoa, nhom]), {'c-dc', 'c-an', 'c-vay'});
    });
  });

  group('dungDanhSachGan', () {
    test('⭐ chiều tiền chặn gán sai: khoản CHI không bao giờ được đoán sang danh mục THU', () {
      final mo = BoPhanLoaiGhiChu.hoc([..._mau('grab', 'c-luong', 12), ..._mau('grab', 'c-dc', 3)]);
      final ds = dungDanhSachGan(giaoDich: [_gd('grab')], chonDuoc: _chonDuoc, mo: mo, tatCap: const {});
      expect(ds, hasLength(1));
      expect(ds.single.doan?.categoryId, isNot('c-luong'),
          reason: 'gắn Lương cho một khoản chi là đảo chiều tiền trong mọi thống kê');
    });

    test('đoán được thì mang danh mục và câu lý do của B1', () {
      final mo = BoPhanLoaiGhiChu.hoc([..._mau('grab', 'c-dc', 8), ..._mau('com trua', 'c-an', 4)]);
      final ds = dungDanhSachGan(giaoDich: [_gd('Grab')], chonDuoc: _chonDuoc, mo: mo, tatCap: const {});
      expect(ds.single.doan?.categoryId, 'c-dc');
      expect(ds.single.lyDo, 'Bạn thường ghi “Grab” cho Di chuyển (8/8 lần).');
    });

    test('mo == null → mọi dòng không có dự đoán, danh sách vẫn đủ dòng', () {
      final ds = dungDanhSachGan(
        giaoDich: [_gd('grab'), _gd('com trua'), _gd('grab', cat: 'c-dc')],
        chonDuoc: _chonDuoc,
        mo: null,
        tatCap: const {},
      );
      expect(ds, hasLength(2));
      expect(ds.every((d) => d.doan == null && d.lyDo == null), isTrue);
    });

    test('cặp đang bị thôi gợi ý (tatCap) thì không đoán', () {
      final mo = BoPhanLoaiGhiChu.hoc([..._mau('grab', 'c-dc', 8), ..._mau('com trua', 'c-an', 4)]);
      final ds = dungDanhSachGan(
          giaoDich: [_gd('grab')], chonDuoc: _chonDuoc, mo: mo, tatCap: {('grab', 'c-dc')});
      expect(ds.single.doan, isNull);
    });

    test('thứ tự: có dự đoán trước (xác suất giảm dần), rồi không có (ngày mới nhất trước)', () {
      final mo = BoPhanLoaiGhiChu.hoc([
        ..._mau('grab', 'c-dc', 9),
        ..._mau('com trua', 'c-an', 4),
        ..._mau('com', 'c-dc', 1),
      ]);
      final ds = dungDanhSachGan(
        giaoDich: [
          _gd('xyz cu', ngay: DateTime(2026, 9, 1)),
          _gd('com trua', ngay: DateTime(2026, 9, 2)),
          _gd('xyz moi', ngay: DateTime(2026, 9, 20)),
          _gd('grab', ngay: DateTime(2026, 9, 3)),
        ],
        chonDuoc: _chonDuoc,
        mo: mo,
        tatCap: const {},
      );
      final coDoan = ds.takeWhile((d) => d.doan != null).toList();
      expect(coDoan, hasLength(2));
      expect(ds.skip(2).every((d) => d.doan == null), isTrue,
          reason: 'dòng có dự đoán đứng trước — người dùng duyệt phần máy đã làm trước');
      expect(coDoan[0].doan!.xacSuat, greaterThanOrEqualTo(coDoan[1].doan!.xacSuat));
      expect(ds.skip(2).map((d) => d.giaoDich.note).toList(), ['xyz moi', 'xyz cu']);
    });

    test('lyDo khác null đúng khi doan khác null', () {
      final mo = BoPhanLoaiGhiChu.hoc([..._mau('grab', 'c-dc', 8), ..._mau('com trua', 'c-an', 4)]);
      final ds = dungDanhSachGan(
        giaoDich: [_gd('grab'), _gd('xyz'), _gd('')],
        chonDuoc: _chonDuoc,
        mo: mo,
        tatCap: const {},
      );
      for (final d in ds) {
        expect(d.lyDo != null, d.doan != null);
      }
    });
  });
}
