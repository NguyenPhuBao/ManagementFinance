/// Tool `tong_quan_tai_chinh` — phần CHÉP của `ai_edge` (spec mở rộng tool
/// 2026-09-27 §4.2). Mọi con số là của `ThongKeKy` và các hàm domain của trang
/// Phân tích (`thuNhapCua`, `tyLeTietKiem`, `dongTienTuDo`, `thayDoiTaiSan`,
/// `duNoRong`); ở đây không cộng, không trừ.
///
/// Ba chỗ khác spec, kèm lý do:
/// - **Không có `Tổng thu`**: nó đứng cạnh `Thu nhập` thì câu *"thu nhập
///   15.135.000 đ"* (thật ra là tổng thu, gồm cả tiền thu nợ) lọt `kiemNhan` — từ
///   khoá của nhãn *Tổng thu* là "thu", và câu ấy có chữ "thu". Tool này sinh
///   ra đúng để phân biệt hai con số ấy (E1), nên chỉ mang `Thu nhập`.
/// - **Khoản chi lớn nhất là một HÀNG**, không phải mục tổng hợp có tên: mục
///   có tên đòi câu nêu tên (`kiemNhan`), mà mẫu câu in tổng hợp dạng `nhãn:
///   số` — mẫu câu của chính gói sẽ bị chặn.
/// - Số âm in **dương** dưới nhãn nói rõ chiều (`Chi vượt thu nhập`, `Tài sản
///   giảm`) — cùng lý lẽ `hang_du_bao.dart`.
library;

import '../../analytics/data/analytics_repository.dart';
import '../../analytics/domain/dong_tien_tu_do.dart';
import '../../analytics/domain/tong_tai_san.dart';
import '../../analytics/domain/vai_vay_no.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'ten_ngan_giao_dich.dart';

const String kChuVayNoMoiLuc = 'vay nợ tính mọi thời gian';
const String kChuTaiSanChuaBiet = 'chưa đủ dữ liệu để biết tài sản tăng hay giảm';

/// Nhóm số của tool — câu hỏi nhắc nhóm nào thì tool trả nhóm ấy (mục 9.34:
/// mẫu câu từng liệt kê cả 11 số cho câu chỉ hỏi một). Tập RỖNG = mọi nhóm.
enum NhomTongQuan { thuNhap, chiTieu, taiSan, vayNo }

/// [vayNoMoiLuc]: điểm vay/nợ gộp MỌI THỜI GIAN (không theo kỳ của [tk]);
/// `null` thì bỏ hai con số dư nợ.
KetQuaCongCu hangTongQuan(
  ThongKeKy tk, {
  required DiemVayNo? vayNoMoiLuc,
  required DateTime now,
  required String chuKy,
  Set<NhomTongQuan> nhom = const {},
}) {
  bool co(NhomTongQuan n) => nhom.isEmpty || nhom.contains(n);
  // Điểm cuối của chuỗi vay/nợ là kỳ đang xem; chuỗi rỗng = kỳ không có vay/nợ.
  final vayNo = tk.chuoiVayNo.isEmpty
      ? DiemVayNo(ky: tk.ky)
      : tk.chuoiVayNo.last;
  final thuNhap = thuNhapCua(tong: tk.tong, vayNo: vayNo);
  final tyLe = tyLeTietKiem(thuNhap: thuNhap, chi: tk.tong.chi);
  // G56: từ 2 lần thu nhập trở lên, con số là "gấp N lần" thay cho phần trăm
  // vượt — cùng hàm với khối Nhận xét và thẻ Số dư còn lại.
  final gapLan = soLanChiGapThuNhap(thuNhap: thuNhap, chi: tk.tong.chi);
  final tuDo = tk.chuoi.isNotEmpty && tk.chuoi.length == tk.chuoiVayNo.length
      ? dongTienTuDo(tk.chuoi, tk.chuoiVayNo).last.tuDo
      : null;
  // Thay đổi TRONG KỲ: điểm cuối so với điểm liền trước; `thayDoiTaiSan` trả
  // `null` khi điểm trước rơi vào quãng "chưa biết" (trước giao dịch đầu tiên).
  final doiTaiSan = tk.taiSan.length < 2
      ? null
      : thayDoiTaiSan(
          tk.taiSan.sublist(tk.taiSan.length - 2),
          giaoDichDauTien: tk.giaoDichDauTien,
        );
  final duNo = vayNoMoiLuc == null || !co(NhomTongQuan.vayNo)
      ? null
      : duNoRong(vayNoMoiLuc);
  final sl = tk.soLieu;
  final lonNhat = co(NhomTongQuan.chiTieu) ? sl.khoanChiLonNhat : null;
  final coThuNhap = co(NhomTongQuan.thuNhap);
  final coChiTieu = co(NhomTongQuan.chiTieu);
  final coTaiSan = co(NhomTongQuan.taiSan);

  final ketQua = <String>[
    if (coThuNhap && tyLe != null && tyLe < 0) 'chi vượt thu nhập',
    if (coTaiSan && doiTaiSan != null)
      doiTaiSan > 0
          ? 'tài sản tăng'
          : (doiTaiSan < 0 ? 'tài sản giảm' : 'tài sản không đổi'),
    // Hỏi ĐÍCH DANH về tài sản mà thay đổi là "chưa biết" thì nói ra — im lặng
    // là để người hỏi "tăng hay giảm" nhận về một con số không trả lời gì (N5).
    if (nhom.contains(NhomTongQuan.taiSan) &&
        doiTaiSan == null &&
        tk.taiSan.isNotEmpty)
      kChuTaiSanChuaBiet,
  ];

  return KetQuaCongCu(
    hang: [
      if (lonNhat != null)
        HangSoLieu(
          // B8 ◐: cùng tên ngắn với tool giao dịch (`ten_ngan_giao_dich.dart`).
          ten: tenNganGiaoDich(lonNhat.tieuDe),
          trangThai: 'khoản chi lớn nhất · ${lonNhat.tenDanhMuc} · ${lonNhat.tenVi}',
          canhBao: false,
          soLieu: [
            soTien('Số tiền', lonNhat.soTien, ten: tenNganGiaoDich(lonNhat.tieuDe)),
            soNgayThang('Ngày', lonNhat.ngay, ten: tenNganGiaoDich(lonNhat.tieuDe), now: now),
          ],
        ),
    ],
    tongHop: [
      if (coThuNhap)
        soTien('Thu nhập', thuNhap, nhanKhac: const ['Thu nhập thật']),
      if (coThuNhap || coChiTieu)
        soTien('Tổng chi', tk.tong.chi, nhanKhac: const ['Đã chi', 'Chi']),
      if (coThuNhap && tyLe != null && tyLe >= 0)
        soPhanTram('Tỉ lệ tiết kiệm', tyLe * 100,
            nhanKhac: const ['Để dành', 'Tiết kiệm']),
      if (coThuNhap && tyLe != null && tyLe < 0)
        gapLan != null
            ? soLan('Gấp thu nhập', gapLan)
            : soPhanTram('Chi vượt thu nhập', (tyLe * 100).abs(),
                nhanKhac: const ['Vượt thu nhập']),
      if (coThuNhap && tuDo != null)
        if (tuDo >= 0)
          soTien('Dòng tiền tự do', tuDo)
        else
          soTien('Dòng tiền tự do âm', tuDo.abs(),
              nhanKhac: const ['Dòng tiền tự do thiếu']),
      if (coChiTieu)
        soTien('Chi trung bình mỗi ngày', sl.chiMoiNgay,
            nhanKhac: const ['Chi mỗi ngày', 'Trung bình mỗi ngày']),
      if (coChiTieu && sl.ngayChiNhieuNhat != null) ...[
        soNgayThang('Ngày chi nhiều nhất', sl.ngayChiNhieuNhat!, now: now),
        soTien('Chi ngày nhiều nhất', sl.chiNgayNhieuNhat,
            nhanKhac: const ['Ngày chi nhiều nhất']),
      ],
      if (coTaiSan && tk.taiSan.isNotEmpty)
        soTien('Tổng tài sản', tk.taiSan.last.tong, nhanKhac: const ['Tài sản']),
      if (coTaiSan && doiTaiSan != null)
        if (doiTaiSan >= 0)
          soTien('Tài sản tăng', doiTaiSan,
              nhanKhac: const ['Tài sản thay đổi', 'Tăng'])
        else
          soTien('Tài sản giảm', doiTaiSan.abs(),
              nhanKhac: const ['Tài sản thay đổi', 'Giảm']),
      if (duNo != null) ...[
        soTien('Đang cho vay chưa thu về', duNo.choVayChuaThu,
            nhanKhac: const ['Cho vay chưa thu', 'Đang cho vay', 'Chưa thu về']),
        soTien('Đang nợ', duNo.dangNo, nhanKhac: const ['Còn nợ', 'Nợ']),
      ],
    ],
    chuThem: {
      'ky': chuKy,
      if (duNo != null) 'vay_no': kChuVayNoMoiLuc,
      if (ketQua.isNotEmpty) 'ket_qua': ketQua.join(', '),
    },
    tenLienQuan: [
      if (lonNhat != null) ...[lonNhat.tenDanhMuc, lonNhat.tenVi],
    ],
    // Câu trả lời cho "tăng hay giảm" lúc này là CHỮ, không phải con số.
    chiMauCau: ketQua.contains(kChuTaiSanChuaBiet),
  );
}
