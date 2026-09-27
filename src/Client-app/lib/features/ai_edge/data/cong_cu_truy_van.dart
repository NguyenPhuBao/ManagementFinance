/// Adapter tool `truy_van_giao_dich` — thay `tim_giao_dich` + `tong_ket_thu_chi_ky`
/// từ 2026-09-27 (spec `2026-09-27-tool-truy-van-giao-dich-design.md`). Luồng:
/// bộ chỉnh tham số theo câu hỏi → kiểm MỌI tham số (`ky` bắt buộc — bước 2b)
/// → `timGiaoDich` (trần lớn khi gộp / chọn) → `hangGiaoDich` hoặc
/// `hangNhomGiaoDich`. Không đọc dữ liệu trước khi tham số qua kiểm — không đoán.
///
/// Tiền là **số đồng**: số JSON, hoặc chuỗi toàn chữ số. "500k" / "nửa triệu"
/// bị từ chối kèm ví dụ — quy đổi là việc của mô hình (và của bộ chỉnh, luật 4).
library;

import '../../analytics/data/bao_cao_repository.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../transaction/data/repositories/transaction_repository.dart';
import '../../transaction/domain/gop_giao_dich.dart';
import '../../transaction/domain/khoang_tien.dart';
import '../../transaction/domain/tim_giao_dich.dart';
import '../domain/chinh_tham_so.dart';
import '../domain/chon.dart';
import '../domain/cong_cu.dart';
import '../domain/goi_so.dart';
import '../domain/hang_giao_dich.dart';
import '../domain/hang_nhom_giao_dich.dart';
import '../domain/hang_so_lieu.dart';
import '../domain/loi_tham_so.dart';
import '../domain/ma_ky.dart';
import '../domain/tham_so_mo_hinh.dart';

/// Mã tham số `gop`: liệt kê, hay mỗi hàng một danh mục / ví.
const List<String> kGop = ['khong', 'danh_muc', 'vi'];

/// "Trần lớn": lấy trọn tập khớp để gộp / chọn — cắt ở tầng hàng, không ở tầng
/// tìm (`timGiaoDich` chỉ cắt `dong`, tổng vẫn đếm trọn tập).
const int _kKhongTran = 1 << 20;

class CongCuTruyVan implements CongCu {
  CongCuTruyVan({
    required this.giaoDich,
    required this.nganSach,
    required this.baoCao,
    this.log = print,
  });

  /// Log khi bộ chỉnh tham số đổi gì đó — `print`, không `debugPrint` (bẫy 4.31).
  final void Function(String) log;
  final TransactionRepository giaoDich;
  final BudgetRepository nganSach;
  final BaoCaoRepository baoCao;

  @override
  KhaiBaoCongCu get khaiBao => KhaiBaoCongCu(
        ten: kTenCongCuTruyVan,
        // Câu "Gọi …" lên đầu — mô hình đọc câu đầu trước (lần đo 9).
        moTa: 'Gọi cho MỌI câu về giao dịch, chi tiêu, thu nhập: tổng một kỳ, tiêu gì, '
            'những khoản nào, khoản lớn nhất, danh mục hay ví nào chi nhiều hay ít nhất, có '
            'điều kiện hay không. Liệt kê từng giao dịch (ghi chú, số tiền, ngày, danh mục, '
            'ví) kèm tổng, hoặc gộp theo danh mục / ví khi câu hỏi nói về danh mục hay ví nói '
            'chung. gop: khong = từng giao dịch; danh_muc / vi = mỗi hàng một danh mục / ví '
            'với tổng chi, tổng thu, số giao dịch. chon: nhieu_nhat / it_nhat = chỉ trả hàng '
            'lớn nhất / nhỏ nhất.',
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
            'gop': {
              'type': 'string',
              'enum': kGop,
              'description': 'khong: liệt kê từng giao dịch (mặc định); danh_muc: mỗi hàng '
                  'một danh mục — dùng khi hỏi danh mục nào, theo danh mục; vi: mỗi hàng '
                  'một ví — dùng khi hỏi ví nào, theo ví.',
            },
            'chon': {
              'type': 'string',
              'enum': kChonGiaoDich,
              'description': 'nhieu_nhat: chỉ hàng ${kChuChon['nhieu_nhat']}; it_nhat: chỉ '
                  'hàng ${kChuChon['it_nhat']}. Bỏ trống khi câu không hỏi nhất.',
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
    String cauHoi = '',
  }) async {
    // Bộ chỉnh tham số theo CÂU HỎI (mục 9.28): câu hỏi là nguồn sự thật,
    // tham số của mô hình chỉ là gợi ý. Chạy TRƯỚC mọi phép kiểm.
    final dsVi = await baoCao.watchVi(idaccount).first;
    final dsDm = await baoCao.watchDanhMuc(idaccount).first;
    final chinh = chinhThamSoTimGiaoDich(
      cauHoi,
      args,
      tenDanhMuc: [for (final d in dsDm) d.ten],
      tenVi: [for (final v in dsVi) v.ten],
    );
    if (chinh.ghiChu.isNotEmpty) {
      log('[SLM][tool] chỉnh tham số theo câu hỏi: ${chinh.ghiChu.join('; ')}');
    }
    final a = chinh.args;
    final maKy = a['ky']?.toString().trim() ?? '';
    final ky = _kyCua(maKy, now);
    if (ky == null) return tuChoiGiaTri('ky', maKy, [...kMaKy.keys, kMaKyMoiLuc]);

    final maChieu = a['chieu']?.toString() ?? 'tat_ca';
    final chieu = kChieuTim[maChieu];
    if (chieu == null) return tuChoiGiaTri('chieu', maChieu, kChieuTim.keys);
    final maXep = a['sap_xep']?.toString() ?? 'so_tien';
    final sapXep = kSapXepTim[maXep];
    if (sapXep == null) return tuChoiGiaTri('sap_xep', maXep, kSapXepTim.keys);

    final tu = _soDong(a['so_tien_tu']);
    if (tu.sai) return tuChoiSoTien('so_tien_tu', a['so_tien_tu']);
    final den = _soDong(a['so_tien_den']);
    if (den.sai) return tuChoiSoTien('so_tien_den', a['so_tien_den']);
    final khoang = KhoangTien(tu: tu.so, den: den.so);
    if (!khoang.hopLe) return tuChoiKhoangNguoc(_tho(tu.so!), _tho(den.so!));

    // Hai tham số mới: giá trị trống = mặc định; giá trị lạ → từ chối như mọi enum.
    final maGop = a['gop']?.toString().trim();
    final gop = (maGop == null || maGop.isEmpty) ? 'khong' : maGop;
    if (!kGop.contains(gop)) return tuChoiGiaTri('gop', gop, kGop);
    final maChon = a['chon']?.toString().trim();
    final chon = (maChon == null || maChon.isEmpty) ? null : maChon;
    if (chon != null && !kChonGiaoDich.contains(chon)) {
      return tuChoiGiaTri('chon', chon, kChonGiaoDich);
    }

    // Tham số tên / từ khoá: giá trị giữ chỗ ("tat_ca") nghĩa là KHÔNG LỌC — cổng
    // D lần 1 đo được mô hình dùng nó thế, và tool từng từ chối vì không có danh
    // mục / ví nào tên ấy (bẫy 4.43).
    final tuKhoa = thamSoTen(a['tu_khoa']);
    // Số tiền trong từ khoá: để nguyên thì tìm "500k" trong ghi chú ra 0 khoản —
    // một lượt THÀNH CÔNG, và câu "không có khoản nào" được phép hiện.
    if (tuKhoa != null && laSoTien(tuKhoa)) return tuChoiTuKhoaLaSoTien(tuKhoa);

    final tieuChi = TieuChiTim(
      chieu: chieu,
      khoangTien: khoang.rong ? null : khoang,
      tenDanhMuc: thamSoTen(a['danh_muc']),
      tenVi: thamSoTen(a['vi']),
      tuKhoa: tuKhoa ?? '',
      sapXep: sapXep,
    );
    final canTron = gop != 'khong' || chon != null;
    final kq = timGiaoDich(
      trongKy: await giaoDich.watchKhoang(idaccount, ky.from, ky.to).first,
      lookup: await nganSach.lookupFor(idaccount),
      viSong: dsVi,
      danhMucSong: dsDm,
      tieuChi: tieuChi,
      now: now,
      toiDa: canTron ? _kKhongTran : kToiDaMucMoiGoi,
    );
    if (kq.loi != null) {
      return hangGiaoDich(kq, tieuChi: tieuChi, chuKy: ky.chu, now: now);
    }
    if (gop != 'khong') {
      return hangNhomGiaoDich(
        kq,
        tieuChi: tieuChi,
        theo: gop == 'danh_muc' ? NhomTheo.danhMuc : NhomTheo.vi,
        chuKy: ky.chu,
        chon: chon,
      );
    }
    if (chon == null) {
      return hangGiaoDich(kq, tieuChi: tieuChi, chuKy: ky.chu, now: now);
    }
    // gop=khong + chon: chọn theo TIỀN dù dòng đang xếp theo ngày; tổng hợp vẫn
    // là của trọn tập (`soKhop`, `tongChi`, …), chỉ `dong` còn một.
    final theoTien = [...kq.dong]..sort((x, y) => y.soTien.compareTo(x.soTien));
    final mot = theoTien.isEmpty
        ? const <DongTimThay>[]
        : [chon == 'nhieu_nhat' ? theoTien.first : theoTien.last];
    final cat = KetQuaTimGiaoDich(
      dong: mot,
      soKhop: kq.soKhop,
      tongChi: kq.tongChi,
      tongThu: kq.tongThu,
      tongChuyen: kq.tongChuyen,
      tenDanhMucKhop: kq.tenDanhMucKhop,
      tenViKhop: kq.tenViKhop,
    );
    return hangGiaoDich(cat, tieuChi: tieuChi, chuKy: ky.chu, now: now, chon: chon);
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
