/// Adapter tool `tim_giao_dich`: kiểm và dịch tham số → `kyTuMa` →
/// `watchKhoang` · `lookupFor` · `watchVi` / `watchDanhMuc` → `timGiaoDich`
/// → `hangGiaoDich`. Mọi tham số kiểm TRƯỚC khi đọc dữ liệu — không đoán.
///
/// Tiền là **số đồng**: số JSON, hoặc chuỗi toàn chữ số. "500k" / "nửa triệu"
/// bị từ chối kèm ví dụ — quy đổi là việc của mô hình, và phép đo cổng D chấm
/// đúng việc ấy (spec mục 1.2 hàng 9). Bảng quy đổi "k / củ" để bước 3.
library;

import '../../analytics/data/bao_cao_repository.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../transaction/data/repositories/transaction_repository.dart';
import '../../transaction/domain/khoang_tien.dart';
import '../../transaction/domain/tim_giao_dich.dart';
import '../domain/cong_cu.dart';
import '../domain/goi_so.dart';
import '../domain/hang_chi_tieu.dart';
import '../domain/hang_giao_dich.dart';
import '../domain/hang_so_lieu.dart';
import '../domain/loi_tham_so.dart';
import '../domain/tham_so_mo_hinh.dart';

class CongCuGiaoDich implements CongCu {
  CongCuGiaoDich({
    required this.giaoDich,
    required this.nganSach,
    required this.baoCao,
  });

  final TransactionRepository giaoDich;
  final BudgetRepository nganSach;
  final BaoCaoRepository baoCao;

  @override
  KhaiBaoCongCu get khaiBao => KhaiBaoCongCu(
        ten: kTenCongCuGiaoDich,
        moTa: 'Tìm và liệt kê TỪNG giao dịch (ghi chú, số tiền, ngày, danh mục, ví) theo '
            'kỳ, khoảng số tiền, chiều tiền (khoản chi, khoản thu, chuyển ví), danh mục, '
            'ví, từ khoá trong ghi chú. Gọi khi hỏi đã tiêu gì, những khoản nào, khoản trên '
            'hay dưới một số tiền, lần gần nhất là khi nào. Tổng chi theo danh mục thì dùng '
            'chi_tieu_theo_ky. so_tien_tu, so_tien_den: số đồng, ví dụ 500000.',
        thamSo: {
          'type': 'object',
          'properties': {
            'ky': {
              'type': 'string',
              'enum': kMaKy.keys.toList(),
              'description': '${[
                for (final e in kMaKy.entries) '${e.key} = ${e.value}',
              ].join('; ')}. Mặc định thang_nay.',
            },
            'chieu': {
              'type': 'string',
              'enum': kChieuTim.keys.toList(),
              'description': 'khoan_chi: khoản chi; khoan_thu: khoản thu; chuyen_vi: '
                  'chuyển giữa hai ví; tat_ca: mọi loại (mặc định).',
            },
            'so_tien_tu': {'type': 'number', 'description': 'Số đồng tối thiểu.'},
            'so_tien_den': {'type': 'number', 'description': 'Số đồng tối đa.'},
            'danh_muc': {'type': 'string', 'description': 'Tên danh mục.'},
            'vi': {'type': 'string', 'description': 'Tên ví.'},
            'tu_khoa': {'type': 'string', 'description': 'Từ khoá trong ghi chú.'},
            'sap_xep': {
              'type': 'string',
              'enum': kSapXepTim.keys.toList(),
              'description': 'so_tien: lớn nhất trước (mặc định); moi_nhat: mới nhất '
                  'trước — dùng khi hỏi lần gần nhất, gần đây.',
            },
          },
        },
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
  }) async {
    final maKy = args['ky']?.toString() ?? 'thang_nay';
    final ky = kyTuMa(maKy, now);
    if (ky == null) return tuChoiGiaTri('ky', maKy, kMaKy.keys);

    final maChieu = args['chieu']?.toString() ?? 'tat_ca';
    final chieu = kChieuTim[maChieu];
    if (chieu == null) return tuChoiGiaTri('chieu', maChieu, kChieuTim.keys);
    final maXep = args['sap_xep']?.toString() ?? 'so_tien';
    final sapXep = kSapXepTim[maXep];
    if (sapXep == null) return tuChoiGiaTri('sap_xep', maXep, kSapXepTim.keys);

    final tu = _soDong(args['so_tien_tu']);
    if (tu.sai) return tuChoiSoTien('so_tien_tu', args['so_tien_tu']);
    final den = _soDong(args['so_tien_den']);
    if (den.sai) return tuChoiSoTien('so_tien_den', args['so_tien_den']);
    final khoang = KhoangTien(tu: tu.so, den: den.so);
    if (!khoang.hopLe) return tuChoiKhoangNguoc(_tho(tu.so!), _tho(den.so!));

    // Tham số tên / từ khoá: giá trị giữ chỗ ("tat_ca") nghĩa là KHÔNG LỌC — cổng
    // D lần 1 đo được mô hình dùng nó thế, và tool từng từ chối vì không có danh
    // mục / ví nào tên ấy (bẫy 4.43).
    final tuKhoa = thamSoTen(args['tu_khoa']);
    // Số tiền trong từ khoá: để nguyên thì tìm "500k" trong ghi chú ra 0 khoản —
    // một lượt THÀNH CÔNG, và câu "không có khoản nào" được phép hiện.
    if (tuKhoa != null && laSoTien(tuKhoa)) return tuChoiTuKhoaLaSoTien(tuKhoa);

    final tieuChi = TieuChiTim(
      chieu: chieu,
      khoangTien: khoang.rong ? null : khoang,
      tenDanhMuc: thamSoTen(args['danh_muc']),
      tenVi: thamSoTen(args['vi']),
      tuKhoa: tuKhoa ?? '',
      sapXep: sapXep,
    );
    final kq = timGiaoDich(
      trongKy: await giaoDich.watchKhoang(idaccount, ky.from, ky.to).first,
      lookup: await nganSach.lookupFor(idaccount),
      viSong: await baoCao.watchVi(idaccount).first,
      danhMucSong: await baoCao.watchDanhMuc(idaccount).first,
      tieuChi: tieuChi,
      now: now,
      toiDa: kToiDaMucMoiGoi,
    );
    return hangGiaoDich(kq, tieuChi: tieuChi, chuKy: kMaKy[maKy]!, now: now);
  }
}

/// Số đồng từ tham số của mô hình: số JSON, hoặc chuỗi toàn chữ số.
/// `(so: null, sai: false)` = không truyền; `sai` = có truyền mà không đọc được.
({double? so, bool sai}) _soDong(Object? v) {
  if (v == null || (v is String && v.trim().isEmpty)) {
    return (so: null, sai: false);
  }
  final so = switch (v) {
    num n => n.toDouble(),
    String s when RegExp(r'^\d+$').hasMatch(s.trim()) => double.parse(s.trim()),
    _ => null,
  };
  if (so == null || so < 0) return (so: null, sai: true);
  return (so: so, sai: false);
}

/// Số đồng in thô cho lời từ chối — mô hình vừa gửi đúng dạng này.
String _tho(double v) => v == v.roundToDouble() ? v.round().toString() : '$v';
