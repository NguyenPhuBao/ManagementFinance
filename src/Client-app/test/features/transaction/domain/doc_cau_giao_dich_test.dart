/// C2 — đọc một câu thành các ô của form Thêm giao dịch (spec `2026-09-28-c2-nhap-giao-dich-bang-cau-design.md` §2).
/// Hàm thuần, chỉ luật: ô nào không đọc được thì `null` và form GIỮ NGUYÊN ô ấy — không bao giờ bịa số.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/transaction/domain/doc_cau_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../../category/presentation/category_test_fakes.dart';

void main() {
  // Thứ Tư 30/9/2026, 15 giờ.
  final now = DateTime(2026, 9, 30, 15);
  KetQuaDocCau doc(String cau) => docCauGiaoDich(cau, now: now, vi: const [], chonDuoc: const []);

  group('§2.1 số tiền — bốn cách nói', () {
    const bang = {
      'ăn phở 45k': 45000.0,
      'cafe 45 k': 45000.0,
      'bún 45 nghìn': 45000.0,
      'bún 45 ngàn': 45000.0,
      'bun 45 nghin': 45000.0,
      'tiền nhà 2tr': 2000000.0,
      'tiền nhà 2 triệu': 2000000.0,
      'sửa xe 1tr2': 1200000.0,
      'laptop 1tr200': 1200000.0,
      'đồng hồ 1tr25': 1250000.0,
      'học phí 1,2 triệu': 1200000.0,
      'đồ 1.5tr': 1500000.0,
      'mua đt 2 củ': 2000000.0,
      'nhậu 2 lít': 200000.0,
      'nhậu 3 xị': 300000.0,
      'năm mươi nghìn tiền gửi xe': 50000.0,
      'một triệu rưỡi tiền điện': 1500000.0,
      'nam muoi nghin gui xe': 50000.0,
      'ăn trưa 45.000': 45000.0,
      'ăn trưa 45000': 45000.0,
      'ăn trưa 45.000đ': 45000.0,
      'ăn trưa 45000 đồng': 45000.0,
      'đổ 2 lít xăng 50k': 50000.0,
    };
    for (final e in bang.entries) {
      test('"${e.key}"', () => expect(doc(e.key).soTien, e.value, reason: e.key));
    }

    test('"2 ly cà phê" → không đọc: số trần dưới 1.000 là số lượng', () {
      expect(doc('2 ly cà phê').soTien, isNull);
    });

    test('hai số tiền cùng hạng → số đầu + cảnh báo', () {
      final r = doc('ăn sáng 30k, grab 50k');
      expect(r.soTien, 30000);
      expect(r.canhBao.single, contains('nhiều số tiền'));
    });

    test('lít đứng sau k: "đổ 2 lít xăng 50k" không cảnh báo nhiều số tiền', () {
      expect(doc('đổ 2 lít xăng 50k').canhBao, isEmpty);
    });

    test('14 chữ số → không đọc + cảnh báo (trần numeric(15,2))', () {
      final r = doc('chuyển 12345678901234');
      expect(r.soTien, isNull);
      expect(r.canhBao, isNotEmpty);
    });

    test('số điện thoại (0 đứng đầu) và năm ("năm 2026") không phải tiền', () {
      final r = doc('nạp thẻ 0912345678 100k');
      expect(r.soTien, 100000);
      expect(r.canhBao, isEmpty);
      final r2 = doc('học phí năm 2026 2tr');
      expect(r2.soTien, 2000000);
      expect(r2.canhBao, isEmpty);
    });

    test('ngày không phải tiền', () {
      final r = doc('ngày 5/9 mua sách 120k');
      expect(r.soTien, 120000);
      expect(r.ngay, DateTime(2026, 9, 5));
    });

    test('⚠️ số chữ mơ hồ → không điền, kèm cảnh báo — không bao giờ bịa số', () {
      final r = doc('một triệu hai tiền sách');
      expect(r.soTien, isNull, reason: '"một triệu hai" là 1.200.000 hay 1.000.000 + chữ khác — không chắc thì không điền');
      expect(r.canhBao, isNotEmpty);
      final r2 = doc('mấy trăm nghìn tiền chợ');
      expect(r2.soTien, isNull);
      expect(r2.canhBao, isNotEmpty);
    });
  });

  group('§2.2 loại', () {
    test('từ chỉ thu → thu', () {
      expect(doc('nhận lương 9tr').loai, 'thu');
      expect(doc('bán xe đạp 2tr').loai, 'thu');
      expect(doc('hoàn tiền 50k').loai, 'thu');
      expect(doc('lãi tiết kiệm 120k').loai, 'thu');
      expect(doc('lì xì 500k').loai, 'thu');
      expect(doc('được cho 500k').loai, 'thu');
      expect(doc('thưởng tết 3tr').loai, 'thu');
      expect(doc('nhan luong 9tr').loai, 'thu', reason: 'gõ không dấu');
    });

    test('vay / nợ → null, để người dùng chọn chiều', () {
      expect(doc('thu nợ anh Nam 500k').loai, isNull);
      expect(doc('vay tiền bạn 2tr').loai, isNull);
    });

    test('câu trơn → null (form giữ chiều đang chọn)', () {
      expect(doc('ăn phở 45k').loai, isNull);
    });

    test('⚠️ bỏ dấu cả câu là đọc sai: "bạn" không phải "bán", "lại" không phải "lãi", "thường" không phải "thưởng"', () {
      expect(doc('ăn với bạn 200k').loai, isNull);
      expect(doc('mua lại áo 200k').loai, isNull);
      expect(doc('cơm bình thường 40k').loai, isNull);
      expect(doc('an voi ban 200k').loai, isNull, reason: '"ban" không dấu có thể là bạn — không đoán');
      expect(doc('mua được áo 200k').loai, isNull, reason: '"được" một mình không phải khoản thu');
    });

    test('"thứ 2" không làm câu thành khoản thu', () {
      final r = doc('thứ 2 đổ xăng 50k');
      expect(r.loai, isNull);
      expect(r.ngay, DateTime(2026, 9, 28));
    });
  });

  group('§2.3 ngày', () {
    test('hôm qua → 29/9; không nêu → null', () {
      expect(doc('hôm qua ăn phở 45k').ngay, DateTime(2026, 9, 29));
      expect(doc('ăn phở 45k').ngay, isNull);
    });
  });

  group('§2.7 ghi chú', () {
    test('bỏ số tiền và ngày; giữ dấu và chữ hoa', () {
      expect(doc('hôm qua ăn Phở 45k').ghiChu, 'ăn Phở');
    });
    test('bỏ luôn "hết / mất / tốn" đứng ngay trước số tiền, và "đồng" ngay sau', () {
      expect(doc('ăn phở hết 45k').ghiChu, 'ăn phở');
      expect(doc('ăn trưa 45000 đồng với bạn').ghiChu, 'ăn trưa với bạn');
    });
    test('số tiền thứ hai (không dùng) ở lại ghi chú; dấu câu gọn lại', () {
      expect(doc('ăn sáng 30k, grab 50k').ghiChu, 'ăn sáng, grab 50k');
    });
    test('ngày có chữ "ngày" bỏ cả cụm', () {
      expect(doc('ngày 5/9 mua sách 120k').ghiChu, 'mua sách');
    });
    test('câu tách dấu (NFD) → ghi chú dựng sẵn (NFC)', () {
      expect(doc(unorm.nfd('hôm qua ăn phở 45k')).ghiChu, 'ăn phở');
    });
  });

  group('§2.4 ví', () {
    final tcb = makeWallet(id: 'w-tcb', name: 'Techcombank').copyWith(type: 'bank');
    final chinh = makeWallet(id: 'w-cash', name: 'Ví chính');
    final mb = makeWallet(id: 'w-mb', name: 'MB').copyWith(type: 'bank');
    KetQuaDocCau docVi(String cau, List<Wallet> vi) =>
        docCauGiaoDich(cau, now: now, vi: vi, chonDuoc: const []);

    test('tên ví nêu trong câu → ví ấy; ghi chú bỏ "ví / bằng / bằng ví" + tên', () {
      final r = docVi('ăn trưa 45k ví Techcombank', [tcb, chinh]);
      expect(r.walletId, 'w-tcb');
      expect(r.ghiChu, 'ăn trưa');
      expect(docVi('ăn trưa 45k bằng ví Techcombank', [tcb, chinh]).ghiChu, 'ăn trưa');
      expect(docVi('ăn trưa bằng techcombank 45k', [tcb, chinh]).ghiChu, 'ăn trưa');
    });

    test('"tiền mặt" → ví tiền mặt khi có ĐÚNG MỘT; hai ví tiền mặt → null, ghi chú giữ chữ ấy', () {
      final r = docVi('45k tiền mặt ăn phở', [tcb, chinh]);
      expect(r.walletId, 'w-cash');
      expect(r.ghiChu, 'ăn phở');
      final hai = docVi('45k tiền mặt ăn phở', [tcb, chinh, makeWallet(id: 'w-cash2', name: 'Ví phụ')]);
      expect(hai.walletId, isNull);
      expect(hai.ghiChu, 'tiền mặt ăn phở');
    });

    test('ví TÊN "Tiền mặt" thắng luật loại ví, kể cả khi có hai ví tiền mặt', () {
      final r = docVi('45k tien mat', [makeWallet(id: 'w-tm', name: 'Tiền mặt'), chinh]);
      expect(r.walletId, 'w-tm');
    });

    test('tên ví ngắn chỉ nhận ngay sau chữ "ví"', () {
      expect(docVi('45k MB', [mb, chinh]).walletId, isNull);
      expect(docVi('45k ví MB', [mb, chinh]).walletId, 'w-mb');
    });
  });

  group('§2.5 danh mục', () {
    final anUong = makeCategory(id: 'c-an', name: 'Ăn uống');
    final diChuyen = makeCategory(id: 'c-dc', name: 'Di chuyển');
    final tietKiemDm = makeCategory(id: 'c-tk', name: 'Tiết kiệm');
    final luong = makeCategory(id: 'c-luong', name: 'Lương', classify: 'thu');
    final choVay = makeCategory(id: 'c-vay', name: 'Cho vay', classify: 'vay_no');
    final thuKhac = makeCategory(id: 'c-thu', name: 'Thu khác', classify: 'thu');
    final nhom = makeCategory(id: 'c-nhom', name: 'Sinh hoạt', isGroup: true);
    final chonDuoc = [anUong, diChuyen, tietKiemDm, luong, choVay, thuKhac, nhom];
    List<MauGhiChu> mau(String ghiChu, String cat, int so) => [
          for (var i = 0; i < so; i++)
            MauGhiChu(categoryId: cat, amTiet: amTietCua(ghiChu), ngay: DateTime(2026, 8, 1 + i)),
        ];
    final mo = BoPhanLoaiGhiChu.hoc([
      ...mau('grab', 'c-dc', 5),
      ...mau('pho bo', 'c-an', 4),
      ...mau('luong thang', 'c-luong', 3),
      ...mau('me gui', 'c-thu', 3),
    ]);
    KetQuaDocCau docDm(String cau, {List<Wallet> vi = const [], BoPhanLoaiGhiChu? m}) =>
        docCauGiaoDich(cau, now: now, vi: vi, chonDuoc: chonDuoc, mo: m);

    test('tên danh mục nêu trong câu → danh mục ấy; không phải B1; ghi chú GIỮ tên', () {
      final r = docDm('45k ăn uống với bạn', m: mo);
      expect(r.categoryId, 'c-an');
      expect(r.doan, isNull);
      expect(r.lyDoDanhMuc, isNull);
      expect(r.ghiChu, 'ăn uống với bạn');
    });

    test('không nêu → B1 đoán trên ghi chú đã rút, kèm doan và câu lý do', () {
      final r = docDm('hôm qua grab 50k', m: mo);
      expect(r.categoryId, 'c-dc');
      expect(r.doan, isNotNull);
      expect(r.lyDoDanhMuc, contains('Di chuyển'));
    });

    test('không có mô hình → null', () {
      expect(docDm('grab 50k').categoryId, isNull);
    });

    test('câu nói chiều THU → danh mục chi không được chọn (hopLeTheoChieu của C1)', () {
      expect(docDm('được cho 500k ăn uống').categoryId, isNull,
          reason: '"Ăn uống" là danh mục chi — câu đã nói khoản thu');
      expect(docDm('nhận lương 9tr ăn uống').categoryId, 'c-luong',
          reason: '"Lương" là danh mục thu có tên trong câu');
    });

    test('câu nói chiều THU → B1 chỉ đoán trong danh mục thu / vay-nợ', () {
      // "grab" học ra Di chuyển (chi); câu nói thu thì Di chuyển không hợp lệ, B1 không được trả nó.
      expect(docDm('được cho 500k grab', m: mo).categoryId, isNot('c-dc'));
    });

    test('câu KHÔNG nói chiều → B1 được chọn cả danh mục thu, như thẻ gợi ý của màn', () {
      final r = docDm('mẹ gửi 2tr', m: mo);
      expect(r.loai, isNull, reason: 'tiền đề: câu không có từ chỉ thu');
      expect(r.categoryId, 'c-thu',
          reason: 'lọc theo đoạn Chi đang chọn thì không bao giờ ra danh mục thu — người dùng chốt theo nếp màn');
    });

    test('nhóm không bao giờ được chọn', () {
      expect(docDm('45k sinh hoạt').categoryId, isNull);
    });

    test('tên ví không bị đọc lại thành danh mục cùng tên', () {
      final r = docDm('45k ví Tiết kiệm', vi: [makeWallet(id: 'w-tk', name: 'Tiết kiệm')]);
      expect(r.walletId, 'w-tk');
      expect(r.categoryId, isNull);
    });
  });

  group('cauDaDien — dòng tóm tắt dưới ô (§3)', () {
    test('đủ các ô, theo thứ tự tiền · loại · ngày · ví · danh mục', () {
      final kq = doc('hôm qua nhận lương 9tr');
      expect(cauDaDien(kq, tenVi: 'Tiền mặt', tenDanhMuc: 'Lương', now: now),
          'Đã điền: 9.000.000 đ · Thu nhập · Hôm qua · Tiền mặt · Lương');
    });
    test('chỉ nêu ô đã đổi; ngày xa thì dd/mm, khác năm thì kèm năm', () {
      expect(cauDaDien(doc('45k'), now: now), 'Đã điền: 45.000 đ');
      expect(cauDaDien(doc('5/9 mua sách'), now: now), 'Đã điền: 05/09');
      expect(cauDaDien(doc('5/9/2025 mua sách'), now: now), 'Đã điền: 05/09/2025');
      expect(cauDaDien(doc('hôm nay 45k'), now: now), 'Đã điền: 45.000 đ · Hôm nay');
    });
    test('không đọc được gì → câu mời điền tay', () {
      expect(cauDaDien(doc('xin chào'), now: now), kCauChuaDocDuoc);
    });
  });

  group('§2.8 cachDocSoTien — mọi cách đọc hợp lệ của số trong câu', () {
    Set<double> doc(String c) => cachDocSoTien(c, now: now);

    test('tiếng lóng: "ba chục" = 30.000; "năm chục" = 50.000', () {
      expect(doc('cà phê mất ba chục'), contains(30000));
      expect(doc('đổ xăng năm chục'), contains(50000));
    });
    test('"một triệu hai" = 1.200.000, "2 triệu 5" = 2.500.000, "2k5" = 2.500', () {
      expect(doc('tiền điện một triệu hai'), contains(1200000));
      expect(doc('tiền nhà 2 triệu 5'), contains(2500000));
      expect(doc('gửi xe 2k5'), contains(2500));
    });
    test('số trần 10–999 → × 1.000; một chữ số là số lượng', () {
      expect(doc('ăn phở 45'), contains(45000));
      expect(doc('mua 2 ly trà sữa'), isEmpty, reason: '"2 ly" không bao giờ thành 2.000 đ');
    });
    test('cụm luật không chọn vẫn là cách đọc hợp lệ (lít, số thứ hai)', () {
      expect(doc('đổ 2 lít xăng 50k'), containsAll([200000, 50000]));
    });
    test('ngày, số điện thoại, năm không phải số tiền', () {
      expect(doc('ngày 5/9 nạp 0912345678 năm 2026'), isEmpty);
    });
  });

  group('§2.8 hợp nhất AI — AI đề xuất, luật kiểm', () {
    final tcb = makeWallet(id: 'w-tcb', name: 'Techcombank').copyWith(type: 'bank');
    final chinh = makeWallet(id: 'w-cash', name: 'Tiền mặt');
    final anUong = makeCategory(id: 'c-an', name: 'Ăn uống');
    final diChuyen = makeCategory(id: 'c-dc', name: 'Di chuyển');
    final luong = makeCategory(id: 'c-luong', name: 'Lương', classify: 'thu');
    final chonDuoc = [anUong, diChuyen, luong];
    KetQuaDocCau docAi(String cau, KetQuaAi ai, {BoPhanLoaiGhiChu? mo}) =>
        docCauGiaoDich(cau, now: now, vi: [tcb, chinh], chonDuoc: chonDuoc, mo: mo, ai: ai);

    test('KetQuaAi.tuThamSo: số dạng chuỗi, rỗng / 0 / khong_ro → null', () {
      final a = KetQuaAi.tuThamSo({'so_tien': '30000', 'loai': 'khong_ro', 'vi': '', 'ghi_chu': ' cà phê '});
      expect(a.soTien, 30000);
      expect(a.loai, isNull);
      expect(a.vi, isNull);
      expect(a.ghiChu, 'cà phê');
      expect(KetQuaAi.tuThamSo({'so_tien': 0}).soTien, isNull);
    });

    test('⭐ số tiền AI là một cách đọc hợp lệ → dùng; luật không đọc được "ba chục"', () {
      final r = docAi('cà phê với Nam mất ba chục', const KetQuaAi(soTien: 30000));
      expect(r.soTien, 30000);
      expect(r.quaAi, isTrue);
    });

    test('⭐ số tiền AI KHÔNG có trong câu → bỏ, giữ số của luật (không bao giờ bịa số)', () {
      expect(docAi('ăn phở 45k', const KetQuaAi(soTien: 450000)).soTien, 45000);
      expect(docAi('mua 2 ly trà sữa', const KetQuaAi(soTien: 2000)).soTien, isNull);
    });

    test('"một triệu hai": luật không điền (mơ hồ), AI chọn 1.200.000 → dùng, bỏ cảnh báo số chữ', () {
      final luat = docCauGiaoDich('tiền điện một triệu hai', now: now, vi: const [], chonDuoc: const []);
      expect(luat.soTien, isNull, reason: 'tiền đề');
      final r = docAi('tiền điện một triệu hai', const KetQuaAi(soTien: 1200000));
      expect(r.soTien, 1200000);
      expect(r.canhBao, isNot(contains(kCanhBaoSoChuChuaRo)));
    });

    test('loại: AI "chi" / "thu" được dùng; câu có nợ / vay → null như luật', () {
      expect(docAi('tiền mẹ gửi 2tr', const KetQuaAi(loai: 'thu')).loai, 'thu');
      expect(docAi('thu nợ anh Nam 500k', const KetQuaAi(loai: 'thu')).loai, isNull);
    });

    test('ngày: luật đọc chắc thì LUẬT THẮNG; luật không đọc được thì ngày AI khi qua kiểm', () {
      expect(docAi('hôm qua ăn phở 45k', const KetQuaAi(ngay: '20/09/2026')).ngay, DateTime(2026, 9, 29));
      expect(docAi('thứ sáu tuần trước ăn lẩu 300k', const KetQuaAi(ngay: '18/09/2026')).ngay,
          DateTime(2026, 9, 25),
          reason: 'luật đọc được "thứ sáu tuần trước" = 25/9 — AI tính lệch một tuần thì bị bỏ');
      expect(docAi('đầu tháng đóng học phí 2tr', const KetQuaAi(ngay: '01/09/2026')).ngay, DateTime(2026, 9, 1),
          reason: 'luật không đọc "đầu tháng" — AI lấp chỗ ấy');
    });

    test('ngày AI bị chặn: câu không có chữ thời gian, tương lai quá 7 ngày, quá 366 ngày, không có trên lịch', () {
      expect(docAi('ăn phở 45k', const KetQuaAi(ngay: '20/09/2026')).ngay, isNull,
          reason: 'câu không nói thời gian — AI không được đổi ngày');
      expect(docAi('tôi ăn phở 45k', const KetQuaAi(ngay: '20/09/2026')).ngay, isNull,
          reason: '"tôi" bỏ dấu là "toi" (= tối) — không phải chữ thời gian');
      expect(docAi('tuần sau đóng học 2tr', const KetQuaAi(ngay: '15/10/2026')).ngay, isNull);
      expect(docAi('tháng trước ăn 45k', const KetQuaAi(ngay: '01/09/2025')).ngay, isNull);
      expect(docAi('tháng trước ăn 45k', const KetQuaAi(ngay: '31/02/2026')).ngay, isNull);
    });

    test('ví: tên ví nêu trong câu → luật thắng; luật không thấy → tên AI phải có thật', () {
      expect(docAi('45k ví Techcombank', const KetQuaAi(vi: 'Tiền mặt')).walletId, 'w-tcb');
      expect(docAi('quẹt thẻ techcom 45k', const KetQuaAi(vi: 'Techcombank')).walletId, 'w-tcb');
      expect(docAi('quẹt thẻ 45k', const KetQuaAi(vi: 'Vietcombank')).walletId, isNull, reason: 'không có ví ấy');
    });

    test('⚠️ ví: câu KHÔNG nhắc ví thì AI không được tự điền ví (Realme 2026-09-30: 9/10 câu AI trả "Tiền mặt")', () {
      expect(docAi('cà phê với Nam mất ba chục', const KetQuaAi(soTien: 30000, vi: 'Tiền mặt')).walletId, isNull);
      expect(docAi('45k techcom', const KetQuaAi(vi: 'Techcombank')).walletId, 'w-tcb',
          reason: 'viết tắt tên ví là có nhắc ví');
      expect(docAi('tiền điện 45k', const KetQuaAi(vi: 'Tiền mặt')).walletId, isNull,
          reason: '"tiền" là chữ thường gặp, không phải nhắc ví Tiền mặt');
    });

    test('ngày: AI trả HÔM NAY khi luật không đọc được = AI không biết ngày → không tuyên bố gì', () {
      expect(docAi('đầu tháng đóng học phí 2tr', const KetQuaAi(ngay: '30/09/2026')).ngay, isNull,
          reason: 'Realme 2026-09-30: AI trả hôm nay cho "đầu tháng" — dòng tóm tắt nói "Hôm nay" là sai');
    });

    test('ghi chú: AI được BỚT chữ, không được THÊM chữ', () {
      expect(docAi('hôm qua ăn phở với bạn 45k', const KetQuaAi(ghiChu: 'ăn phở')).ghiChu, 'ăn phở');
      expect(docAi('hôm qua ăn phở 45k', const KetQuaAi(ghiChu: 'ăn phở bò Hà Nội')).ghiChu, 'ăn phở',
          reason: '"bò Hà Nội" không có trong câu');
    });

    test('danh mục: tên trong câu → B1 khi chắc → AI (hợp chiều) → không', () {
      final mo = BoPhanLoaiGhiChu.hoc([
        for (var i = 0; i < 6; i++)
          MauGhiChu(categoryId: 'c-dc', amTiet: amTietCua('grab'), ngay: DateTime(2026, 8, 1 + i)),
        for (var i = 0; i < 6; i++)
          MauGhiChu(categoryId: 'c-an', amTiet: amTietCua('pho bo'), ngay: DateTime(2026, 8, 1 + i)),
      ]);
      expect(docAi('45k ăn uống', const KetQuaAi(danhMuc: 'Di chuyển'), mo: mo).categoryId, 'c-an',
          reason: 'tên nêu trong câu');
      final b1 = docAi('grab 50k', const KetQuaAi(danhMuc: 'Ăn uống'), mo: mo);
      expect(b1.categoryId, 'c-dc', reason: 'B1 thắng khi nó chắc — người dùng chốt');
      expect(b1.doan, isNotNull);
      final ai = docAi('bún chả 45k', const KetQuaAi(danhMuc: 'Ăn uống'), mo: mo);
      expect(ai.categoryId, 'c-an', reason: 'B1 im (chưa thấy "bún chả") → danh mục AI');
      expect(ai.doan, isNull, reason: 'không phải B1 — không ghi phản hồi B1');
      expect(docAi('bún chả 45k', const KetQuaAi(danhMuc: 'Ăn vặt')).categoryId, isNull, reason: 'không có thật');
      expect(docAi('bún chả 45k', const KetQuaAi(loai: 'thu', danhMuc: 'Ăn uống')).categoryId, isNull,
          reason: 'AI nói thu mà chọn danh mục chi — không hợp chiều');
    });

    test('không có KetQuaAi → quaAi false (đường luật)', () {
      expect(doc('ăn phở 45k').quaAi, isFalse);
    });
  });

  group('không đọc được gì', () {
    test('câu không có ô nào đọc được → khongDocDuocGi, ghi chú là cả câu', () {
      final r = doc('xin chào');
      expect(r.khongDocDuocGi, isTrue);
      expect(r.ghiChu, 'xin chào');
    });
    test('có số tiền thì không phải "không đọc được gì"', () {
      expect(doc('45k').khongDocDuocGi, isFalse);
    });
  });
}
