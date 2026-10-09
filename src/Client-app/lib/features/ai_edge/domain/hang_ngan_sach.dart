/// Tool `danh_sach_ngan_sach` — hàng theo TÊN ngân sách kèm trạng thái, đã chi,
/// hạn mức, tỉ lệ, còn lại, số ngày còn lại (spec 4b mục 3.4). Không tính gì:
/// `remaining`, `rawPercentSpent`, `isOverBudget` là getter của `BudgetEntity`;
/// nhịp từ `budgetPaceOf`. "Tổng còn lại" cộng `remaining` của mọi ngân sách
/// đang chạy — đúng phép thẻ tổng trang Ngân sách đang hiện (câu 2 bảng 5.6).
///
/// [chon] (spec tool truy vấn 2026-09-27, mục 4 — E18): lọc hoặc chọn theo tỉ
/// lệ đã dùng — `duoi_nua` / `tren_nua` giữ mọi hàng thoả, `nhieu_nhat` /
/// `it_nhat` giữ một hàng. Tổng hợp vẫn cộng MỌI ngân sách đang chạy; "Số ngân
/// sách khớp" chỉ có khi lọc, và 0 khớp là `rongTheoBoLoc` (không phải "không
/// có ngân sách"). Mã nội bộ `kChonSapHet` (G2, 2026-10-04): ngân sách chạm ngưỡng
/// cảnh báo riêng hoặc đã vượt; 0 khớp là KẾT LUẬN (`ket_qua` + chỉ mẫu câu).
///
/// [ten] (G2 cổng F, E10): tên ngân sách câu hỏi nêu (`tenNeuTrongCau` — tên
/// lấy từ chính [dangChay]) → chỉ hàng ấy, và BỎ "Tổng còn lại" của mọi ngân sách.
///
/// [nhipTheoNganSach] (dự án C việc hai): trạng thái nhịp theo nhịp riêng đã học
/// — cùng phép với chip trang chi tiết; thiếu khoá = chi đều.
library;

import '../../budget/data/models/budget_entity.dart';
import '../../budget/domain/budget_pace.dart';
import '../../budget/domain/de_xuat_ngan_sach.dart';
import '../../budget/domain/nhip_chi.dart';
import 'chon.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';
import 'tai_phan_bo.dart';

String chuNhipNganSach(BudgetPaceStatus s) => switch (s) {
      BudgetPaceStatus.fast => 'tiêu nhanh',
      BudgetPaceStatus.onTrack => 'đúng nhịp',
      BudgetPaceStatus.slow => 'tiêu chậm',
    };

KetQuaCongCu hangNganSach(
  List<BudgetView> dangChay, {
  required DateTime now,
  String? chon,
  String? ten,
  Map<String, NhipChi?> nhipTheoNganSach = const {},
}) {
  if (chon != null && chon != kChonSapHet && !kChon.contains(chon)) {
    return tuChoiGiaTri('chon', chon, kChon);
  }
  // `chua_dat` / `can_doi` không phải phép lọc trên ngân sách đang chạy — tool
  // phải rẽ sang `hangChuaDatNganSach` / `hangCanDoiNganSach` TRƯỚC khi tới đây;
  // tới đây là lỗi lập trình.
  if (chon == 'chua_dat' || chon == 'can_doi') {
    throw ArgumentError.value(chon, 'chon', 'đi đường riêng của mã này');
  }
  // G2 cổng F (E10): câu nêu tên một ngân sách → chỉ ngân sách ấy.
  final nguon = ten == null ? dangChay : [for (final v in dangChay) if (v.displayName == ten) v];
  // Căng nhất trước — thứ tự đáng chú ý, không phải thứ tự CSDL.
  final sap = [...nguon]..sort(
      (x, y) => y.budget.rawPercentSpent.compareTo(x.budget.rawPercentSpent));
  // Ngưỡng "một nửa" là 0,5 của rawPercentSpent — đúng phép trang Ngân sách,
  // không làm tròn trước khi so.
  final khop = switch (chon) {
    'nhieu_nhat' => sap.take(1).toList(),
    'it_nhat' => sap.isEmpty ? <BudgetView>[] : [sap.last],
    'duoi_nua' => [for (final v in sap) if (v.budget.rawPercentSpent < 0.5) v],
    'tren_nua' => [for (final v in sap) if (v.budget.rawPercentSpent >= 0.5) v],
    // G2: ngưỡng cảnh báo riêng — `isNearLimit` trả false cho ngân sách đã vượt,
    // nên hỏi cả hai.
    kChonSapHet => [for (final v in sap) if (v.budget.isNearLimit || v.budget.isOverBudget) v],
    _ => sap,
  };
  // G2: không ngân sách nào sắp hết là một CÂU TRẢ LỜI, không phải lỗi tìm kiếm
  // (cùng lý do H3 / F15 của `can_doi`).
  final khongSapHet = chon == kChonSapHet && khop.isEmpty;

  var tongConLai = 0.0;
  for (final v in dangChay) {
    tongConLai += v.budget.remaining;
  }

  final hang = <HangSoLieu>[];
  for (final v in khop.take(kToiDaMucMoiGoi)) {
    final b = v.budget;
    final nhip = budgetPaceOf(b, now, nhipChi: nhipTheoNganSach[b.id]);
    final ten = v.displayName;
    hang.add(HangSoLieu(
      ten: ten,
      trangThai: b.isOverBudget ? 'vượt hạn mức' : chuNhipNganSach(nhip.status),
      canhBao: b.isOverBudget,
      soLieu: [
        soTien('Đã chi', b.spent, ten: ten),
        soTien('Hạn mức', b.amount, ten: ten),
        soPhanTram('Tỉ lệ', b.rawPercentSpent * 100, ten: ten),
        // Đã vượt thì "còn lại" là số âm người đọc phải tự đảo nghĩa — bỏ,
        // trạng thái đã nói "vượt hạn mức".
        if (!b.isOverBudget) soTien('Còn lại', b.remaining, ten: ten),
        soNgay('Còn', nhip.daysLeft, ten: ten),
      ],
    ));
  }
  return KetQuaCongCu(
    hang: hang,
    tongHop: [
      // Hỏi một ngân sách có tên mà gói mang tổng của MỌI ngân sách thì mô hình
      // đọc tổng ấy (E10: "tổng còn lại 1.340.000" cho câu hỏi ngân sách ăn uống).
      if (ten == null) soTien('Tổng còn lại', tongConLai),
      soDem('Số ngân sách', dangChay.length),
      if (chon != null && !khongSapHet) soDem('Số ngân sách khớp', khop.length),
    ],
    chuThem: {
      // ⚠️ "chưa" phải đứng trong ba từ trước "vượt hạn mức" — cụm báo động của
      // `kiemGiong`; "chưa ngân sách nào sắp hết hay vượt hạn mức" bị chính mẫu câu chặn.
      if (khongSapHet) 'ket_qua': 'chưa ngân sách nào sắp hết, cũng chưa vượt hạn mức',
    },
    boLoc: [
      if (chon != null && !khongSapHet) chon == kChonSapHet ? kChuChonSapHet : kChuChon[chon]!,
    ],
    rongTheoBoLoc: chon != null && khop.isEmpty && !khongSapHet,
    doiTuongRong: 'ngân sách',
    chiMauCau: khongSapHet,
    soChuaKe: khop.length - hang.length,
    danhTuChuaKe: 'ngân sách',
  );
}

/// `chon=chua_dat` (spec 2026-09-27 chắn oan + chưa đặt): danh mục CHI đang tiêu
/// mà chưa có ngân sách — chính `chonDeXuat` của thẻ *Chưa đặt ngân sách*, mỗi
/// hàng một danh mục với *Chi trung bình mỗi tháng* (= `suggestAmount`).
/// [goi] `null` (tài khoản quá trẻ / không ứng viên) hay rỗng → `rongTheoBoLoc`;
/// [soNganSach] là số ngân sách đang chạy, để mô hình không đọc "0 danh mục
/// chưa đặt" thành "không có ngân sách". Câu người dùng tự hỏi 2026-09-27 từng
/// nhận *"Không có danh mục nào chưa đặt ngân sách"* — sai, vì không tool nào có.
KetQuaCongCu hangChuaDatNganSach(GoiDeXuat? goi, {required int soNganSach}) {
  final ds = goi?.ds ?? const <DeXuatNganSach>[];
  return KetQuaCongCu(
    hang: [
      for (final d in ds.take(kToiDaMucMoiGoi))
        HangSoLieu(
          ten: d.tenDanhMuc,
          trangThai: kChuChon['chua_dat'],
          canhBao: false,
          soLieu: [soTien('Chi trung bình mỗi tháng', d.mucThang, ten: d.tenDanhMuc)],
        ),
    ],
    tongHop: [
      soDem('Số ngân sách', soNganSach),
      soDem('Số danh mục chưa đặt', goi?.soUngVien ?? 0),
    ],
    boLoc: [kChuChon['chua_dat']!],
    rongTheoBoLoc: ds.isEmpty,
    doiTuongRong: 'danh mục',
  );
}

/// `chon=can_doi` (lát 3 Task 11, spec mở rộng tool §5.3): kế hoạch tái phân bổ
/// — **cùng** kế hoạch với thẻ *Đề xuất cân đối* và thông báo `budgetRebalance`
/// (nguồn `keHoachTaiPhanBoTu`), tool chỉ chép số. Hàng đầu là ngân sách thâm
/// hụt lớn nhất, các hàng sau là nguồn bù theo thứ tự của kế hoạch.
/// [kh] `null` = không ngân sách nào thâm hụt đủ ngưỡng → kết luận *"không ngân
/// sách nào cần cân đối"*, chỉ mẫu câu (H3 cổng F lần 2, F15: bản trước là
/// `rongTheoBoLoc`, in *"Cần cân đối — không có ngân sách nào khớp"* — đọc như
/// một lỗi tìm kiếm trong khi đó là câu trả lời).
/// Tool không áp dụng gì (bất biến ④): `ghi_chu` nói áp dụng ở trang Ngân sách.
KetQuaCongCu hangCanDoiNganSach(KeHoachTaiPhanBo? kh, {required int soNganSach}) {
  final hang = <HangSoLieu>[];
  if (kh != null) {
    final ten = kh.thieu.displayName;
    hang.add(HangSoLieu(
      ten: ten,
      trangThai: 'thâm hụt',
      canhBao: true,
      soLieu: [
        soTien('Thâm hụt', kh.thamHut, ten: ten),
        soTien('Dự phóng', kh.duPhong, ten: ten),
        soTien('Hạn mức', kh.thieu.budget.amount, ten: ten),
      ],
    ));
    for (final d in kh.dong.take(kToiDaMucMoiGoi - 1)) {
      final tenNguon = d.nguon.displayName;
      hang.add(HangSoLieu(
        ten: tenNguon,
        trangThai: 'giảm bớt',
        canhBao: false,
        soLieu: [
          soTien('Chuyển', d.soTien, ten: tenNguon),
          soTien('Dư địa', d.duDia, ten: tenNguon),
        ],
      ));
    }
  }
  final thieuNguon = kh?.trangThai == TrangThaiKeHoach.thieuNguonBu;
  return KetQuaCongCu(
    hang: hang,
    tongHop: [
      soDem('Số ngân sách', soNganSach),
      soDem('Số ngân sách cần bù', kh == null ? 0 : 1),
      if (kh != null && kh.dong.isNotEmpty) soTien('Tổng chuyển', kh.tongCat),
      if (thieuNguon) soTien('Còn thiếu sau khi bù', kh!.soThieu),
    ],
    chuThem: {
      'ket_qua': kh == null
          ? 'không ngân sách nào cần cân đối'
          : thieuNguon
              ? 'thiếu nguồn bù'
              : 'đủ nguồn bù',
      if (kh != null) 'ghi_chu': 'chỉ là gợi ý, áp dụng ở trang Ngân sách',
    },
    boLoc: [if (kh != null) kChuChon['can_doi']!],
    doiTuongRong: 'ngân sách',
    chiMauCau: kh == null,
  );
}
