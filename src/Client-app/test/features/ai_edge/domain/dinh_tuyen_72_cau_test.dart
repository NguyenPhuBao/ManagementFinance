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
/// Câu nguyên văn từ buổi đo trọn 72 câu (Realme, 2026-09-28, `congF_tron.sh`);
/// ba chữ gõ gấp đôi vì bàn phím Telex (`muaxxe`, `tesst`, `Netfflix` — bẫy 4.41)
/// đổi lại thành chữ máy thật nhận được.
library;

import 'package:flowmoney/features/ai_edge/domain/chinh_tham_so.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, (String, String?)> kBang72Cau = {
  'A13': ('Hoa don nao qua han?', 'danh_sach_hoa_don'), // A2
  'A15': ('Vi nao dang am?', 'danh_sach_vi'), // A2
  'A8': ('Thang nay toi chi nhieu nhat vao danh muc nao?', null),
  'A3': ('Ngan sach nao sap het?', 'danh_sach_ngan_sach'), // A2
  'A2': ('Con bao nhieu tien ngan sach thang nay?', 'danh_sach_ngan_sach'), // A2
  'A9': ('Thang truoc toi chi bao nhieu?', null),
  'DC1': ('Lai suat tiet kiem cua toi la bao nhieu?', null),
  'DC2': ('Thang nay toi chi bao nhieu?', null),
  'B1': ('khi nao toi dat muc tieu muaxe', 'danh_sach_muc_tieu'), // A2
  'B2': ('moi thang toi can de danh bao nhieu cho muaxe', 'danh_sach_muc_tieu'),
  'B3': ('thang sau toi nen dat ngan sach bao nhieu', 'goi_y_han_muc'), // A2
  'B4': ('ngan sach an uong nen dat bao nhieu', 'goi_y_han_muc'), // A2
  'B1c': ('hoa don di h0c con phai tra bao nhieu', 'danh_sach_hoa_don'), // A2
  'C1': ('thang nay toi tieu gi tren 500k', null),
  'C2': ('hom qua toi da chi nhung gi', null),
  'C3': ('hom nay toi co giao dich nao khong', null),
  'C4': ('tuan nay co khoan chi nao duoi 100 nghin khong', null),
  'C5': ('tuan truoc toi da tieu nhung khoan nao', null),
  'C6': ('thang truoc toi co khoan chi nao tren 1 trieu khong', null),
  'C7': ('cac khoan chi hon nua trieu trong quy nay', null),
  'C8': ('nam nay toi co khoan thu nao tu 5 trieu tro len khong', null),
  'C9': ('liet ke cac khoan chi tu 200k den 1 trieu thang nay', null),
  'C10': ('thang nay toi nhan duoc nhung khoan thu nao', null),
  'C11': ('thang nay toi da chuyen tien sang vi tiet kiem nhung lan nao', null),
  'C12': ('liet ke cac khoan an uong thang nay', null),
  'C13': ('vi tien mat thang nay chi nhung gi', null),
  'C14': ('thang nay toi chi gi cho mua sam tu vi tien mat', null),
  'C15': ('lan gan nhat toi chi cho di chuyen la ngay nao', null),
  'C16': ('5 khoan chi gan day nhat cua toi', null),
  'C17': ('tim cac giao dich co ghi chu hoa don', null),
  'C18': ('khoan chi lon nhat thang nay la gi', null),
  'C19': ('cac khoan chi cho giao duc tu vi test', null),
  'C20': ('lan cuoi toi nap tien cho muc tieu muaxe la ngay nao', null),
  'DC3': ('cac khoan chi cho danh muc abc thang nay', null),
  'E1': ('Tong thu nhap thang nay cua toi la bao nhieu?', 'tong_quan_tai_chinh'),
  'E2': ('Thang 9 toi da tieu het bao nhieu tien?', null),
  'E3': ('Danh muc nao toi it tieu nhat trong thang?', null),
  'E4': ('Co khoan chi nao khong qua 30 nghin trong thang nay khong?', null),
  'E5': ('Ke tu dau nam toi da chi cho giai tri tong cong bao nhieu?', null),
  'E6': ('Nhung lan toi nap tien vao muc tieu MuaDT', null),
  'E7': ('Vi Tiet kiem hien co bao nhieu tien?', 'danh_sach_vi'),
  'E8': ('Hoa don Netflix khi nao den han?', 'danh_sach_hoa_don'), // A2
  'E9': ('Toi co bao nhieu hoa don chua tra?', 'danh_sach_hoa_don'), // A2
  'E10': ('Ngan sach an uong con lai bao nhieu?', 'danh_sach_ngan_sach'), // A2
  'E11': ('Muc tieu nao dang cham ke hoach?', 'danh_sach_muc_tieu'), // A2
  'E12': ('Toi co may vi tat ca?', 'danh_sach_vi'), // A2
  'E13': ('Thang nay toi chi nhieu hon hay it hon thang truoc?', null),
  'E14': ('Tong tai san cua toi la bao nhieu?', 'danh_sach_vi'), // A2
  'E15': ('Toi da cho vay bao nhieu va thu ve duoc bao nhieu?', null),
  'E16': ('Khoan thu lon nhat nam nay la gi?', null),
  'E17': ('Tuan nay toi co tieu gi khong?', null),
  'E18': ('Ngan sach nao toi chua dung den mot nua?', 'danh_sach_ngan_sach'), // A2
  'E19': ('Trong quy nay khoan chi nao lon nhat?', null),
  'E20': ('Toi chi cho di chuyen trung binh moi thang bao nhieu?', 'goi_y_han_muc'), // A2
  'E21': ('Hom nay la ngay bao nhieu?', null),
  'E22': ('Gia vang hom nay bao nhieu?', null),
  'F1': ('thang 8 toi chi bao nhieu', null),
  'F2': ('tu 1/9 den 15/9 toi chi nhung gi', null),
  'F3': ('thang nay chi nhieu hon hay it hon thang truoc', null),
  'F4': ('tien trong vi co du tra hoa don khong', 'du_bao_dong_tien'),
  'F5': ('tra het hoa don thi con bao nhieu', 'du_bao_dong_tien'),
  'F6': ('thu nhap thang nay cua toi la bao nhieu', 'tong_quan_tai_chinh'),
  'F7': ('toi de danh duoc bao nhieu phan tram', 'tong_quan_tai_chinh'),
  'F8': ('ngay nao thang nay toi chi nhieu nhat', 'tong_quan_tai_chinh'),
  'F9': ('toi dang cho vay bao nhieu chua thu ve', 'tong_quan_tai_chinh'),
  'F10': ('toi co nhung danh muc nao', 'danh_sach_danh_muc'),
  'F11': ('thang toi toi phai tra hoa don nao', 'danh_sach_hoa_don'), // A2
  'F12': ('hoa don nao tu tra', 'danh_sach_hoa_don'), // A2
  'F13': ('vi co du tien trich cho muc tieu khong', 'danh_sach_muc_tieu'),
  'F14': ('ky trich tiep theo cua MuaDT la khi nao', 'danh_sach_muc_tieu'),
  'F15': ('nen chuyen bot ngan sach nao sang ngan sach nao', 'danh_sach_ngan_sach'),
  'F16': ('gia vang hom nay bao nhieu', null),
};

void main() {
  test('đủ 72 câu', () => expect(kBang72Cau.length, 72));
  for (final e in kBang72Cau.entries) {
    test('${e.key}: ${e.value.$1}', () {
      expect(congCuTheoCauHoi(e.value.$1), e.value.$2, reason: e.key);
    });
  }
}
