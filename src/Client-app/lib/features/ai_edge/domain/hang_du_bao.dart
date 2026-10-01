/// Tool `du_bao_dong_tien` — phần CHÉP của `ai_edge` (spec mở rộng tool
/// 2026-09-27 §4.1). Mọi con số là của `DuBaoDongTien` — đúng khối *Dự báo 30
/// ngày tới* của trang Phân tích; ở đây không cộng, không trừ.
///
/// Tool này sinh ra cho câu 16–17 của bảng đo chặng 3 (mục 5.6
/// `docs/AI_AGENT_ARCHITECTURE.md`): *"tiền trong ví có đủ trả hoá đơn không"*,
/// *"trả hết hoá đơn thì còn bao nhiêu"* — câu đòi một phép TRỪ giữa hai gói,
/// thứ bất biến *"lớp AI không tính"* cấm mô hình làm. Tool trả con số đã trừ
/// sẵn.
///
/// ⚠️ Nhãn KHÔNG mang chữ số: *"Cam kết 30 ngày tới"* làm mẫu câu của chính gói
/// bị `kiemSo` chặn (30 không phải một số liệu). Tầm nhìn đi bằng **tên liên
/// quan** — cùng đường với tên đối tượng có chữ số (bước 1c).
library;

import '../../analytics/domain/du_bao_dong_tien.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';

const String kTinhTrangDuBaoDu = 'đủ trả mọi cam kết';
const String kTinhTrangDuBaoThieu = 'thiếu tiền cho cam kết';
const String kTinhTrangDuBaoChuaCoVi = 'chưa có ví';

/// Các cách gọi tầm nhìn — bộ kiểm số bỏ chúng khỏi câu trước khi trích số.
const List<String> kTenTamNhinDuBao = [
  '$kSoNgayDuBao ngày tới',
  '$kSoNgayDuBao ngày sắp tới',
  '$kSoNgayDuBao ngày',
];

String _chuLoai(CamKet c) {
  final loai = switch (c.loai) {
    LoaiCamKet.hoaDon => 'hoá đơn',
    LoaiCamKet.trichTuDong => 'trích tự động',
  };
  // "đã" chứ không "·": mẫu câu in "Kiem hoá đơn đã quá hạn: …", và `kiemTen` đọc
  // chữ ngay sau từ loại "hoá đơn" làm tên — "· quá hạn" không khớp tên nào
  // nên mẫu câu của chính gói bị chặn (lộ ra ở A3, 2026-09-29). Cùng chữ với
  // trạng thái quá hạn của tool hoá đơn.
  return c.quaHan ? '$loai đã quá hạn' : loai;
}

/// [db] `null` = tài khoản chưa có ví sống nào (`duBaoCua` trả `null`) — một
/// lượt THÀNH CÔNG không số, không phải lời từ chối.
KetQuaCongCu hangDuBao(DuBaoDongTien? db, {required DateTime now}) {
  if (db == null) {
    return const KetQuaCongCu(
      hang: [],
      tongHop: [],
      chuThem: {'tinh_trang': kTinhTrangDuBaoChuaCoVi},
    );
  }
  final conTieuDuoc = db.conTieuDuoc;
  final theoNganSach = db.conTieuDuocTheoNganSach;
  // Ví thiếu đứng ĐẦU: mô hình đọc từ trên xuống, và đó là thứ phải nói trước.
  final hang = <HangSoLieu>[
    for (final v in db.viThieu)
      HangSoLieu(
        ten: v.ten,
        trangThai: 'ví không đủ',
        canhBao: true,
        soLieu: [
          soTien('Thiếu', v.thieu, ten: v.ten),
          soNgayThang('Ngày', v.ngay, ten: v.ten, now: now),
        ],
      ),
    // `camKet` đã xếp theo ngày rồi theo tên — gần nhất trước.
    // A3: kỳ quá hạn của cùng hoá đơn gộp MỘT hàng — `duBaoCua` dồn chúng về
    // hôm nay nên in từng kỳ là in cùng tên, cùng ngày hai lần. Phép cộng là
    // của `gopCamKetQuaHan` (analytics) — ở đây chỉ chép.
    for (final g in gopCamKetQuaHan(db.camKet))
      HangSoLieu(
        ten: g.dau.ten,
        trangThai: _chuLoai(g.dau),
        canhBao: g.dau.quaHan,
        soLieu: [
          if (g.soKy > 1) ...[
            soTien('Tổng quá hạn', g.tong,
                ten: g.dau.ten, nhanKhac: const ['Số tiền', 'Phải trả']),
            if (g.moiKy != null) soTien('Mỗi kỳ', g.moiKy!, ten: g.dau.ten),
            soDem('Số kỳ quá hạn', g.soKy, ten: g.dau.ten, nhanKhac: const ['Số kỳ']),
          ] else
            soTien('Số tiền', g.tong, ten: g.dau.ten),
          soNgayThang('Ngày', g.dau.ngay, ten: g.dau.ten, now: now),
        ],
      ),
  ].take(kToiDaMucMoiGoi).toList();
  return KetQuaCongCu(
    hang: hang,
    tongHop: [
      soTien('Số dư hiện tại', db.soDuHienTai, nhanKhac: const ['Số dư']),
      soTien('Tổng cam kết', db.tongCamKet,
          nhanKhac: const ['Phải trả', 'Phải chi', 'Cam kết']),
      // Âm thì in số DƯƠNG dưới nhãn "thiếu": mô hình nói "thiếu 50.000 đ", và
      // một số âm trong gói không khớp con số dương của câu ấy.
      if (conTieuDuoc >= 0)
        soTien('Còn tiêu được', conTieuDuoc, nhanKhac: const ['Còn lại', 'Còn'])
      else
        soTien('Thiếu sau cam kết', conTieuDuoc.abs(),
            nhanKhac: const ['Thiếu', 'Còn thiếu']),
      if (db.coNganSach)
        if (theoNganSach >= 0)
          soTien('Nếu tiêu đúng ngân sách còn', theoNganSach,
              nhanKhac: const ['Theo ngân sách còn', 'Ngân sách còn'])
        else
          soTien('Nếu tiêu đúng ngân sách thiếu', theoNganSach.abs(),
              nhanKhac: const ['Theo ngân sách thiếu', 'Ngân sách thiếu']),
      soDem('Số cam kết', db.camKet.length),
      // Nhãn KHÔNG mở đầu bằng "Ví" (cùng khuôn `hang_muc_tieu.dart`): `kiemTen`
      // đọc chữ sau "ví" là tên ví, và "Ví thiếu: 0" làm mẫu câu của chính gói
      // bị chặn ở MỌI lượt từ khi tool ra đời (lộ ra ở A3, 2026-09-29).
      soDem('Số ví không đủ tiền', db.viThieu.length, nhanKhac: const ['Ví thiếu']),
    ],
    chuThem: {
      'tinh_trang': conTieuDuoc >= 0 && db.viThieu.isEmpty
          ? kTinhTrangDuBaoDu
          : kTinhTrangDuBaoThieu,
    },
    tenLienQuan: [
      ...kTenTamNhinDuBao,
      for (final c in db.camKet)
        if (c.tenVi != null) c.tenVi!,
    ],
  );
}
