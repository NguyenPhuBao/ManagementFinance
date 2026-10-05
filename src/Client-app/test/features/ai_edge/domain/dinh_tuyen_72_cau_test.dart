/// Bảng 72 câu cổng F → tool mà `congCuTheoCauHoi` định tuyến (A2, 2026-09-29).
///
/// Canh chừng điều gì: đổi luật định tuyến là đổi ĐƯỜNG của câu đã đo trên máy
/// thật — phiên một tool thay phiên sáu tool, và mô hình không còn chọn tool nữa.
/// Bảng này bắt mọi câu đổi đường NGOÀI Ý MUỐN: thêm một từ vào danh sách khớp
/// là có thể kéo một câu về giao dịch sang tool khác, im lặng. `null` = phiên
/// sáu tool, mô hình tự chọn.
///
/// Dòng `// A2` là câu A2 (2026-09-29) đưa về phiên một tool — mỗi câu đổi sang
/// đúng tool mà mô hình đã tự chọn ở mốc 72 câu, và cả 18 câu khi ấy đều ✅.
///
/// Từ dự án B (2026-10-02) bảng còn canh ĐƯỜNG GHÉP luật → mô hình nhỏ (nhóm
/// cuối tệp): 31 câu theo luật không đổi đường, bốn câu ngoài phạm vi không bị
/// định tuyến, 37 câu giao dịch chỉ đi phiên sáu tool hoặc tool giao dịch.
///
/// Câu nguyên văn từ buổi đo trọn 72 câu (Realme, 2026-09-28, `congF_tron.sh`);
/// ba chữ gõ gấp đôi vì bàn phím Telex (`muaxxe`, `tesst`, `Netfflix` — bẫy 4.41)
/// đổi lại thành chữ máy thật nhận được.
library;

import 'package:flowmoney/features/ai_edge/domain/chinh_tham_so.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen_hoc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mỗi dòng: (câu, tool mà LUẬT định tuyến, NHÃN).
///
/// Cột NHÃN (dự án B, 2026-10-02) là tool đã trả lời ĐÚNG câu ấy ở mốc 72 câu,
/// hoặc `khong_dinh_tuyen` cho bốn câu ngoài phạm vi. Với 41 câu luật trả
/// `null`, nhãn đối chiếu từ log tool của chính buổi đo (`congF_tron_ketqua.txt`):
/// 37 câu mô hình gọi `truy_van_giao_dich`; DC1 · E22 · F16 bị chặn trước mô
/// hình, E21 mô hình không gọi tool nào. Cột này là nhãn của 72 câu trong bộ
/// huấn luyện (`test/tool/dinh_tuyen/bo_huan_luyen.tsv`).
const Map<String, (String, String?, String)> kBang72Cau = {
  'A13': ('Hoa don nao qua han?', 'danh_sach_hoa_don', 'danh_sach_hoa_don'), // A2
  'A15': ('Vi nao dang am?', 'danh_sach_vi', 'danh_sach_vi'), // A2
  'A8': ('Thang nay toi chi nhieu nhat vao danh muc nao?', null, 'truy_van_giao_dich'),
  'A3': ('Ngan sach nao sap het?', 'danh_sach_ngan_sach', 'danh_sach_ngan_sach'), // A2
  'A2': ('Con bao nhieu tien ngan sach thang nay?', 'danh_sach_ngan_sach', 'danh_sach_ngan_sach'), // A2
  'A9': ('Thang truoc toi chi bao nhieu?', null, 'truy_van_giao_dich'),
  'DC1': ('Lai suat tiet kiem cua toi la bao nhieu?', null, 'khong_dinh_tuyen'),
  'DC2': ('Thang nay toi chi bao nhieu?', null, 'truy_van_giao_dich'),
  'B1': ('khi nao toi dat muc tieu muaxe', 'danh_sach_muc_tieu', 'danh_sach_muc_tieu'), // A2
  'B2': ('moi thang toi can de danh bao nhieu cho muaxe', 'danh_sach_muc_tieu', 'danh_sach_muc_tieu'),
  'B3': ('thang sau toi nen dat ngan sach bao nhieu', 'goi_y_han_muc', 'goi_y_han_muc'), // A2
  'B4': ('ngan sach an uong nen dat bao nhieu', 'goi_y_han_muc', 'goi_y_han_muc'), // A2
  'B1c': ('hoa don di h0c con phai tra bao nhieu', 'danh_sach_hoa_don', 'danh_sach_hoa_don'), // A2
  'C1': ('thang nay toi tieu gi tren 500k', null, 'truy_van_giao_dich'),
  'C2': ('hom qua toi da chi nhung gi', null, 'truy_van_giao_dich'),
  'C3': ('hom nay toi co giao dich nao khong', null, 'truy_van_giao_dich'),
  'C4': ('tuan nay co khoan chi nao duoi 100 nghin khong', null, 'truy_van_giao_dich'),
  'C5': ('tuan truoc toi da tieu nhung khoan nao', null, 'truy_van_giao_dich'),
  'C6': ('thang truoc toi co khoan chi nao tren 1 trieu khong', null, 'truy_van_giao_dich'),
  'C7': ('cac khoan chi hon nua trieu trong quy nay', null, 'truy_van_giao_dich'),
  'C8': ('nam nay toi co khoan thu nao tu 5 trieu tro len khong', null, 'truy_van_giao_dich'),
  'C9': ('liet ke cac khoan chi tu 200k den 1 trieu thang nay', null, 'truy_van_giao_dich'),
  'C10': ('thang nay toi nhan duoc nhung khoan thu nao', null, 'truy_van_giao_dich'),
  'C11': ('thang nay toi da chuyen tien sang vi tiet kiem nhung lan nao', null, 'truy_van_giao_dich'),
  'C12': ('liet ke cac khoan an uong thang nay', null, 'truy_van_giao_dich'),
  'C13': ('vi tien mat thang nay chi nhung gi', null, 'truy_van_giao_dich'),
  'C14': ('thang nay toi chi gi cho mua sam tu vi tien mat', null, 'truy_van_giao_dich'),
  'C15': ('lan gan nhat toi chi cho di chuyen la ngay nao', null, 'truy_van_giao_dich'),
  'C16': ('5 khoan chi gan day nhat cua toi', null, 'truy_van_giao_dich'),
  'C17': ('tim cac giao dich co ghi chu hoa don', null, 'truy_van_giao_dich'),
  'C18': ('khoan chi lon nhat thang nay la gi', null, 'truy_van_giao_dich'),
  'C19': ('cac khoan chi cho giao duc tu vi test', null, 'truy_van_giao_dich'),
  'C20': ('lan cuoi toi nap tien cho muc tieu muaxe la ngay nao', null, 'truy_van_giao_dich'),
  'DC3': ('cac khoan chi cho danh muc abc thang nay', null, 'truy_van_giao_dich'),
  'E1': ('Tong thu nhap thang nay cua toi la bao nhieu?', 'tong_quan_tai_chinh', 'tong_quan_tai_chinh'),
  'E2': ('Thang 9 toi da tieu het bao nhieu tien?', null, 'truy_van_giao_dich'),
  'E3': ('Danh muc nao toi it tieu nhat trong thang?', null, 'truy_van_giao_dich'),
  'E4': ('Co khoan chi nao khong qua 30 nghin trong thang nay khong?', null, 'truy_van_giao_dich'),
  'E5': ('Ke tu dau nam toi da chi cho giai tri tong cong bao nhieu?', null, 'truy_van_giao_dich'),
  'E6': ('Nhung lan toi nap tien vao muc tieu MuaDT', null, 'truy_van_giao_dich'),
  'E7': ('Vi Tiet kiem hien co bao nhieu tien?', 'danh_sach_vi', 'danh_sach_vi'),
  'E8': ('Hoa don Netflix khi nao den han?', 'danh_sach_hoa_don', 'danh_sach_hoa_don'), // A2
  'E9': ('Toi co bao nhieu hoa don chua tra?', 'danh_sach_hoa_don', 'danh_sach_hoa_don'), // A2
  'E10': ('Ngan sach an uong con lai bao nhieu?', 'danh_sach_ngan_sach', 'danh_sach_ngan_sach'), // A2
  'E11': ('Muc tieu nao dang cham ke hoach?', 'danh_sach_muc_tieu', 'danh_sach_muc_tieu'), // A2
  'E12': ('Toi co may vi tat ca?', 'danh_sach_vi', 'danh_sach_vi'), // A2
  'E13': ('Thang nay toi chi nhieu hon hay it hon thang truoc?', null, 'truy_van_giao_dich'),
  'E14': ('Tong tai san cua toi la bao nhieu?', 'danh_sach_vi', 'danh_sach_vi'), // A2
  'E15': ('Toi da cho vay bao nhieu va thu ve duoc bao nhieu?', null, 'truy_van_giao_dich'),
  'E16': ('Khoan thu lon nhat nam nay la gi?', null, 'truy_van_giao_dich'),
  'E17': ('Tuan nay toi co tieu gi khong?', null, 'truy_van_giao_dich'),
  'E18': ('Ngan sach nao toi chua dung den mot nua?', 'danh_sach_ngan_sach', 'danh_sach_ngan_sach'), // A2
  'E19': ('Trong quy nay khoan chi nao lon nhat?', null, 'truy_van_giao_dich'),
  'E20': ('Toi chi cho di chuyen trung binh moi thang bao nhieu?', 'goi_y_han_muc', 'goi_y_han_muc'), // A2
  'E21': ('Hom nay la ngay bao nhieu?', null, 'khong_dinh_tuyen'),
  'E22': ('Gia vang hom nay bao nhieu?', null, 'khong_dinh_tuyen'),
  'F1': ('thang 8 toi chi bao nhieu', null, 'truy_van_giao_dich'),
  'F2': ('tu 1/9 den 15/9 toi chi nhung gi', null, 'truy_van_giao_dich'),
  'F3': ('thang nay chi nhieu hon hay it hon thang truoc', null, 'truy_van_giao_dich'),
  'F4': ('tien trong vi co du tra hoa don khong', 'du_bao_dong_tien', 'du_bao_dong_tien'),
  'F5': ('tra het hoa don thi con bao nhieu', 'du_bao_dong_tien', 'du_bao_dong_tien'),
  'F6': ('thu nhap thang nay cua toi la bao nhieu', 'tong_quan_tai_chinh', 'tong_quan_tai_chinh'),
  'F7': ('toi de danh duoc bao nhieu phan tram', 'tong_quan_tai_chinh', 'tong_quan_tai_chinh'),
  'F8': ('ngay nao thang nay toi chi nhieu nhat', 'tong_quan_tai_chinh', 'tong_quan_tai_chinh'),
  'F9': ('toi dang cho vay bao nhieu chua thu ve', 'tong_quan_tai_chinh', 'tong_quan_tai_chinh'),
  'F10': ('toi co nhung danh muc nao', 'danh_sach_danh_muc', 'danh_sach_danh_muc'),
  'F11': ('thang toi toi phai tra hoa don nao', 'danh_sach_hoa_don', 'danh_sach_hoa_don'), // A2
  'F12': ('hoa don nao tu tra', 'danh_sach_hoa_don', 'danh_sach_hoa_don'), // A2
  'F13': ('vi co du tien trich cho muc tieu khong', 'danh_sach_muc_tieu', 'danh_sach_muc_tieu'),
  'F14': ('ky trich tiep theo cua MuaDT la khi nao', 'danh_sach_muc_tieu', 'danh_sach_muc_tieu'),
  'F15': ('nen chuyen bot ngan sach nao sang ngan sach nao', 'danh_sach_ngan_sach', 'danh_sach_ngan_sach'),
  'F16': ('gia vang hom nay bao nhieu', null, 'khong_dinh_tuyen'),
};

void main() {
  test('đủ 72 câu', () => expect(kBang72Cau.length, 72));

  test('cột nhãn: 31 câu theo luật · 37 câu giao dịch · 4 câu không định tuyến', () {
    final v = kBang72Cau.values;
    expect(v.where((x) => x.$2 != null), hasLength(31));
    expect(v.where((x) => x.$2 != null && x.$3 != x.$2), isEmpty,
        reason: 'câu luật đã định tuyến thì nhãn chính là tool của luật');
    expect(v.where((x) => x.$2 == null && x.$3 == kTenCongCuTruyVan), hasLength(37));
    expect(
        kBang72Cau.entries.where((e) => e.value.$3 == kNhanKhongDinhTuyen).map((e) => e.key),
        ['DC1', 'E21', 'E22', 'F16']);
  });

  for (final e in kBang72Cau.entries) {
    test('${e.key}: ${e.value.$1}', () {
      expect(congCuTheoCauHoi(e.value.$1), e.value.$2, reason: e.key);
    });
  }

  // ĐƯỜNG GHÉP (dự án B, 2026-10-02) — luật trước, bộ định tuyến học sau, với
  // TRỌNG SỐ THẬT. Cổng ra 1–3 của spec mục 6.
  //
  // ⚠️ 72 câu nằm TRONG bộ huấn luyện: nhóm này canh hồi quy (huấn luyện lại mà
  // một câu đã đo bị kéo sang tool khác thì đỏ), KHÔNG đo khả năng tổng quát —
  // phép đo ấy là bộ đo khoá `test/tool/dinh_tuyen/bo_do.tsv`.
  group('đường ghép luật → mô hình', () {
    test('⭐ 31 câu theo luật KHÔNG đổi đường: vẫn tool của luật, nguồn luật', () {
      for (final e in kBang72Cau.entries.where((e) => e.value.$2 != null)) {
        final r = dinhTuyenCauHoi(e.value.$1);
        expect((r.ten, r.nguon), (e.value.$2, NguonDinhTuyen.luat), reason: e.key);
      }
    });

    test('⭐ bốn câu ngoài phạm vi KHÔNG bị định tuyến', () {
      for (final e in kBang72Cau.entries.where((e) => e.value.$3 == kNhanKhongDinhTuyen)) {
        final r = dinhTuyenCauHoi(e.value.$1);
        expect((r.ten, r.nguon), (null, NguonDinhTuyen.khong),
            reason: '${e.key}: mô hình đoán ${r.nhanMoHinh} p=${r.xacSuat}');
      }
    });

    test('⭐ 37 câu giao dịch: phiên sáu tool HOẶC tool giao dịch — không bao giờ tool khác', () {
      final cau = kBang72Cau.entries
          .where((e) => e.value.$2 == null && e.value.$3 == kTenCongCuTruyVan)
          .toList();
      final duoc = <String>[];
      final khong = <String>[];
      for (final e in cau) {
        final r = dinhTuyenCauHoi(e.value.$1);
        expect(r.ten, anyOf(isNull, kTenCongCuTruyVan), reason: e.key);
        expect(r.nguon, r.ten == null ? NguonDinhTuyen.khong : NguonDinhTuyen.moHinh, reason: e.key);
        final p = r.xacSuat!.toStringAsFixed(2);
        (r.ten == null ? khong : duoc)
            .add(r.ten == null ? '${e.key} (${r.nhanMoHinh} p=$p)' : '${e.key} (p=$p)');
      }
      // Danh sách câu ĐỔI ĐƯỜNG — đầu vào của buổi đo máy (Task 8). In ra chứ
      // không `expect` con số: huấn luyện lại là con số đổi, đó không phải lỗi.
      // ignore: avoid_print
      print('[72] định tuyến theo mô hình ${duoc.length}/${cau.length}: ${duoc.join(' · ')}');
      // ignore: avoid_print
      print('[72] ở lại phiên sáu tool ${khong.length}/${cau.length}: ${khong.join(' · ')}');
    });
  });

  // ĐƯỜNG NHANH (spec 2026-10-02 §7, thi công 2026-10-04): câu giao dịch đi đường
  // nhanh khi đường ghép định tuyến về tool giao dịch VÀ luật đọc đủ tham số. Ghim
  // vế LUẬT — đổi luật là đổi đường của câu đã đo; vế mô hình đổi theo mỗi lần huấn
  // luyện lại (không phải lỗi) nên chỉ in, như ca bên trên.
  test('⭐ đường nhanh: luật đọc đủ 34/37 câu giao dịch — C12 ("khoản" trơn), C20 · E6 ("nạp tiền") thì không', () {
    final cau = kBang72Cau.entries.where((e) => e.value.$2 == null && e.value.$3 == kTenCongCuTruyVan);
    final khongDu = {
      for (final e in cau)
        if (!docDuThamSoGiaoDich(e.value.$1)) e.key,
    };
    expect(khongDu, {'C12', 'C20', 'E6'});
    final nhanh = [
      for (final e in cau)
        if (dinhTuyenCauHoi(e.value.$1).ten == kTenCongCuTruyVan && docDuThamSoGiaoDich(e.value.$1)) e.key,
    ];
    // ignore: avoid_print
    print('[72] đi đường nhanh ${nhanh.length}/${cau.length}: ${nhanh.join(' · ')}');
  });
}
