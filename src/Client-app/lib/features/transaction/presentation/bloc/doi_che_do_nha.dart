/// Hai phép dựng state khi form Thêm giao dịch đổi nguồn (spec 2026-11-16 mục 2.1–2.2). Thuần — cubit gọi rồi tự lo việc
/// bất đồng bộ (nạp danh mục, hẹn gợi ý). Tách khỏi cubit vì tệp ấy sát trần 1.200 dòng (quét 23).
library;

import '../../../category/data/models/category_entity.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../data/vi_chung_cho_form_nguon.dart';
import '../../domain/ghep_danh_muc_theo_ten.dart';
import '../state/che_do_nha_form.dart';
import 'them_giao_dich_state.dart';

/// Vào chế độ nhà: giữ số tiền / ghi chú / ngày / đoạn; danh mục ghép theo tên; bỏ mọi thứ chỉ có nghĩa ở cá nhân (thẻ gợi
/// ý, đề xuất từ khoá, tách, chip số tiền của câu, dòng kết quả Nhập nhanh).
ThemGiaoDichState vaoCheDoNha(
  ThemGiaoDichState s, {
  required WalletEntity vi,
  required CheDoNhaForm cheDo,
  required List<CategoryEntity> danhMucNha,
}) =>
    s.copyWith(
      viNguon: vi,
      nhaDangGhi: cheDo,
      danhMuc: ghepDanhMucTheoTen(s.danhMuc, danhMucNha),
      goiY: null,
      deXuat: null,
      daThemTuKhoa: null,
      ketQuaDien: null,
      luaChonTienCau: const [],
      phanTach: const [],
    );

/// Ra chế độ nhà: về ví cá nhân [vi], danh mục ghép ngược theo tên.
ThemGiaoDichState raCheDoNha(
  ThemGiaoDichState s, {
  required WalletEntity vi,
  required List<CategoryEntity> danhMucRieng,
}) =>
    s.copyWith(viNguon: vi, nhaDangGhi: null, danhMuc: ghepDanhMucTheoTen(s.danhMuc, danhMucRieng));

/// Cấu hình chế độ nhà dựng từ nhóm ví chung: chip Chuyển khoản tắt (quyết định 2), quyền hỏi lại lúc Lưu.
CheDoNhaForm cheDoTuNhom(NhomViChung n) => CheDoNhaForm(
      idNha: n.idNha,
      tenNha: n.tenNha,
      choChuyen: false,
      duongChonDanhMuc: n.duongChonDanhMuc,
      conDuocGhi: (_) => n.conDuocGhi(),
    );
