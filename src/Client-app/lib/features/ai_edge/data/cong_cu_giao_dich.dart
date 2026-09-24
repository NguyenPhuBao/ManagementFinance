/// Adapter tool `tim_giao_dich`: kiểm và dịch tham số (`ky` **bắt buộc** — bước
/// 2b) → khoảng đọc (`kyTuMa`, hoặc mọi thời gian cho `moi_luc`) →
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
        // Lần đo 9: "Gọi khi" lên câu đầu — mô hình đọc câu đầu trước.
        moTa: 'Gọi khi câu hỏi có BẤT KỲ điều kiện nào — số tiền (trên, dưới, từ … đến), '
            'ví, danh mục, khoản thu, ghi chú, lần gần nhất — hoặc hỏi đã tiêu gì, chi gì, '
            'những khoản nào, khoản lớn nhất, chuyển tiền sang ví nào. Liệt kê TỪNG giao '
            'dịch (ghi chú, số tiền, ngày, danh mục, ví) kèm tổng của mọi khoản khớp. Chỉ '
            'hỏi tổng chi, tổng thu của một kỳ mà không có điều kiện nào thì dùng '
            'tong_ket_thu_chi_ky.',
        thamSo: {
          'type': 'object',
          'properties': {
            'ky': {
              'type': 'string',
              'enum': [...kMaKy.keys, kMaKyMoiLuc],
              'description': '${[
                for (final e in kMaKy.entries) '${e.key} = ${e.value}',
              ].join('; ')}; $kMaKyMoiLuc = $kChuKyMoiLuc. Câu nêu kỳ nào thì chọn '
                  'đúng kỳ ấy; câu không nêu kỳ (lần gần nhất, lần cuối, gần đây, tìm '
                  'theo ghi chú) thì chọn $kMaKyMoiLuc.',
            },
            'chieu': {
              'type': 'string',
              'enum': kChieuTim.keys.toList(),
              'description': 'khoan_chi: khoản chi (hỏi tiêu, chi, mua); khoan_thu: khoản '
                  'thu (hỏi thu, nhận, lương); chuyen_vi: chuyển giữa hai ví; tat_ca: mọi '
                  'loại (mặc định).',
            },
            'so_tien_tu': {
              'type': 'number',
              'description': 'Số đồng tối thiểu. Câu có "trên", "hơn", "từ … trở lên" kèm '
                  'số tiền thì PHẢI điền. Đổi ra số đồng: 500k = 500000, nửa triệu = '
                  '500000, 1 triệu = 1000000.',
            },
            'so_tien_den': {
              'type': 'number',
              'description': 'Số đồng tối đa. Câu có "dưới", "không quá", "đến" kèm số tiền '
                  'thì PHẢI điền.',
            },
            'danh_muc': {
              'type': 'string',
              'description': 'Tên MỘT danh mục, chỉ khi câu hỏi nêu tên danh mục. Không nêu '
                  'thì BỎ TRỐNG, không điền "tất cả". Tên ví điền vào vi.',
            },
            'vi': {
              'type': 'string',
              'description': 'Tên MỘT ví, chỉ khi câu hỏi nêu tên ví. Không nêu thì BỎ TRỐNG, '
                  'không điền "tất cả".',
            },
            'tu_khoa': {
              'type': 'string',
              'description': 'Chữ cần tìm trong GHI CHÚ, ví dụ tên hoá đơn, tên mục tiêu. '
                  'Không điền số tiền, tên danh mục hay tên ví.',
            },
            'sap_xep': {
              'type': 'string',
              'enum': kSapXepTim.keys.toList(),
              'description': 'so_tien: lớn nhất trước (mặc định), dùng khi hỏi khoản lớn '
                  'nhất; moi_nhat: mới nhất trước, dùng khi hỏi lần gần nhất, lần cuối, gần '
                  'đây.',
            },
          },
          'required': ['ky'],
        },
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
  }) async {
    final maKy = args['ky']?.toString().trim() ?? '';
    final ky = _kyCua(maKy, now);
    if (ky == null) return tuChoiGiaTri('ky', maKy, [...kMaKy.keys, kMaKyMoiLuc]);

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
    return hangGiaoDich(kq, tieuChi: tieuChi, chuKy: ky.chu, now: now);
  }
}

/// Mã kỳ → khoảng đọc + chữ kỳ. `null` = mã lạ hoặc thiếu (spec 2b mục 2.5:
/// `ky` bắt buộc, không tự mặc định tháng này).
({DateTime from, DateTime to, String chu})? _kyCua(String ma, DateTime now) {
  if (ma == kMaKyMoiLuc) {
    // Khoản ghi ngày tương lai vẫn bị `timGiaoDich` bỏ (spec bước 2 mục 1.2 hàng 11).
    return (
      from: DateTime(1970),
      to: DateTime(now.year, now.month, now.day + 1),
      chu: kChuKyMoiLuc,
    );
  }
  final ky = kyTuMa(ma, now);
  return ky == null ? null : (from: ky.from, to: ky.to, chu: kMaKy[ma]!);
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
