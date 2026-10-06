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

    group('đơn vị TỶ sau chữ số (2026-10-02 — trước đó chỉ "một tỷ" viết bằng chữ đọc được)', () {
      const ty = {
        'mua nhà 2 tỷ': 2e9,
        'mua nhà 2 tỉ': 2e9,
        'mua nha 2 ty': 2e9,
        'mua nha 2ty': 2e9,
        'mua đất 1,5 tỷ': 1.5e9,
        'mua đất 1.5 tỉ': 1.5e9,
        'xe 1ty2': 1.2e9,
        'xe 1ty25': 1.25e9,
        'xe 1ty250': 1.25e9,
      };
      for (final e in ty.entries) {
        test('"${e.key}"', () => expect(doc(e.key).soTien, e.value, reason: e.key));
      }

      test('⚠️ "tí" không phải "tỉ": câu CÓ DẤU thì đơn vị phải đúng dấu', () {
        expect(doc('mua 2 tí kẹo').soTien, isNull,
            reason: 'bỏ dấu thì "tí" = "ti" = tỉ — "2 tí kẹo" thành hai tỷ đồng');
        expect(doc('mua 2 tí kẹo 5k').soTien, 5000);
        expect(cachDocSoTien('mua 2 tí kẹo', now: now), isEmpty,
            reason: 'lớp kiểm số của AI cũng không được nhận cách đọc ấy');
      });

      test('"thu 2 tỷ" là thu hai tỷ, không phải thứ Hai', () {
        final r = doc('thu 2 ty tien ban nha');
        expect((r.soTien, r.ngay), (2e9, null));
      });

      test('vượt trần 13 chữ số → không đọc', () {
        expect(doc('gom 20000 tỷ').soTien, isNull);
      });

      test('cách đọc cho lớp kiểm AI: "1 tỷ 2" = 1,2 tỷ, "2 tỷ rưỡi" có 2,5 tỷ… như triệu', () {
        expect(cachDocSoTien('xe 1 tỷ 2', now: now), contains(1.2e9));
        expect(cachDocSoTien('xe 1 ty 2', now: now), contains(1.2e9));
        expect(cachDocSoTien('xe 1ty2', now: now), contains(1.2e9));
        expect(cachDocSoTien('nhà 2 tỷ', now: now), contains(2e9));
      });
    });

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
      expect(docAi('tháng trước ăn lẩu 300k', const KetQuaAi(ngay: '12/08/2026')).ngay, DateTime(2026, 8, 12),
          reason: 'luật không đọc "tháng trước" (không biết ngày nào) — AI lấp chỗ ấy');
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
      expect(docAi('cuối tháng rồi đóng học phí 2tr', const KetQuaAi(ngay: '30/09/2026')).ngay, isNull,
          reason: 'Realme 2026-09-30: AI trả hôm nay cho "đầu tháng" (nay luật đọc được) — dòng tóm tắt nói "Hôm nay" '
              'là sai; "cuối tháng rồi" luật chưa đọc nên vẫn là ca của lớp kiểm này');
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

    group('bước TỪ KHOÁ (người dùng chốt 2026-09-30): tên → B1 → từ khoá → AI', () {
      final moGrab = BoPhanLoaiGhiChu.hoc([
        for (var i = 0; i < 6; i++)
          MauGhiChu(categoryId: 'c-dc', amTiet: amTietCua('grab'), ngay: DateTime(2026, 8, 1 + i)),
        for (var i = 0; i < 6; i++)
          MauGhiChu(categoryId: 'c-an', amTiet: amTietCua('pho bo'), ngay: DateTime(2026, 8, 1 + i)),
      ]);
      KetQuaDocCau docTk(String cau, Map<String, List<String>> tuKhoa, {KetQuaAi? ai, BoPhanLoaiGhiChu? mo}) =>
          docCauGiaoDich(cau, now: now, vi: [tcb, chinh], chonDuoc: chonDuoc, mo: mo, ai: ai, tuKhoa: tuKhoa);

      test('⭐ từ khoá khớp → danh mục ấy, kèm câu lý do và gợi ý nguồn "từ khoá" (Realme: "đổ xăng" từng ra Ăn uống)', () {
        final r = docTk('đổ xăng 50k', {'c-dc': ['xăng']}, ai: const KetQuaAi(danhMuc: 'Ăn uống'));
        expect(r.categoryId, 'c-dc', reason: 'từ khoá đứng TRƯỚC AI');
        expect(r.lyDoDanhMuc, 'Khớp với “xăng” trong ghi chú.');
        expect(r.goiY?.nguon, kNguonGoiYTuKhoa);
        expect(r.doan, isNull, reason: 'không phải B1');
      });

      test('B1 chắc thì B1 THẮNG từ khoá (cùng thứ tự thẻ gợi ý trên màn)', () {
        final r = docTk('grab 50k', {'c-an': ['grab']}, mo: moGrab);
        expect(r.categoryId, 'c-dc');
        expect(r.goiY?.nguon, kNguonGoiYHoc);
      });

      test('từ khoá cũng phải hợp chiều: câu nói THU thì từ khoá của danh mục chi không được chọn', () {
        expect(docTk('được cho 500k tiền xăng', {'c-dc': ['xăng']}).categoryId, isNull);
      });

      test('không từ khoá nào khớp → rơi về AI', () {
        expect(docTk('bún chả 45k', {'c-dc': ['xăng']}, ai: const KetQuaAi(danhMuc: 'Ăn uống')).categoryId, 'c-an');
      });
    });

    test('không có KetQuaAi → quaAi false (đường luật)', () {
      expect(doc('ăn phở 45k').quaAi, isFalse);
    });
  });

  // Người dùng chốt 2026-09-30 (banner "ĐỔI LẦN HAI" + §8 câu 2, 9 của spec): luật chạy trước; chỉ gọi mô hình khi còn
  // ô CÂU CÓ NHẮC mà luật không đọc được — số tiền, ngày, ví. Thu/chi và danh mục không phải ô thiếu (gọi AI vì chúng là
  // gọi gần như mọi câu, ~18 s mỗi câu trên Realme). AI chỉ LẤP ô luật để trống: luật đọc được thì luật thắng.
  group('ĐỔI LẦN HAI — luật trước, AI chỉ lấp ô thiếu (oThieu)', () {
    final tcb = makeWallet(id: 'w-tcb', name: 'Techcombank').copyWith(type: 'bank');
    final chinh = makeWallet(id: 'w-cash', name: 'Tiền mặt');
    KetQuaDocCau luat(String cau) => docCauGiaoDich(cau, now: now, vi: [tcb, chinh], chonDuoc: const []);
    KetQuaDocCau voiAi(String cau, KetQuaAi ai) =>
        docCauGiaoDich(cau, now: now, vi: [tcb, chinh], chonDuoc: const [], ai: ai);

    test('⭐ luật đọc đủ những gì câu nhắc → không ô nào thiếu, màn KHÔNG gọi mô hình', () {
      for (final c in ['ăn phở 45k', 'hôm qua ăn phở 45k tiền mặt', '45k ví Techcombank', 'mua 2 ly trà sữa', 'xin chào']) {
        expect(luat(c).oThieu, isEmpty, reason: c);
      }
    });

    test('số tiền thiếu: luật không đọc được mà câu có số / số chữ đọc được thành tiền', () {
      expect(luat('cà phê với Nam mất ba chục').oThieu, {OThieu.soTien, OThieu.ghiChu},
          reason: 'số chưa đọc được còn nằm trong ghi chú');
      expect(luat('tiền điện một triệu hai').oThieu, {OThieu.soTien, OThieu.ghiChu});
    });

    test('ngày thiếu: luật không đọc được mà câu có chữ thời gian; "tôi" không phải chữ thời gian', () {
      expect(luat('cuối tháng rồi đóng học phí 2tr').oThieu, {OThieu.ngay});
      expect(luat('tôi ăn phở 45k').oThieu, isEmpty);
    });

    test('ví thiếu: luật không đọc được mà câu nhắc ví (thẻ, quẹt, viết tắt tên ví); "tiền" trần không tính', () {
      expect(luat('quẹt thẻ ăn phở 45k').oThieu, {OThieu.vi});
      expect(luat('ăn phở 45k techcom').oThieu, {OThieu.vi});
      expect(luat('tiền điện 45k').oThieu, isEmpty);
    });

    // Người dùng 2026-09-30: "cả ghi chú nữa nếu các lớp trước ko được thì AI sẽ điền" — chọn: ghi chú còn sót số tiền
    // luật không dùng là ô thiếu; AI vẫn chỉ được BỚT chữ; ghi chú trống thì không gọi AI (không có chữ để điền mà không bịa).
    test('⭐ ghi chú còn sót số tiền luật không dùng là ô thiếu; AI dọn bằng cách bớt chữ', () {
      expect(luat('ăn sáng 30k, grab 50k').oThieu, {OThieu.ghiChu});
      final r = voiAi('ăn sáng 30k, grab 50k', const KetQuaAi(ghiChu: 'ăn sáng, grab'));
      expect(r.ghiChu, 'ăn sáng, grab');
      expect(r.oThieu, isEmpty);
      expect(luat('45k tiền mặt').oThieu, isEmpty, reason: 'ghi chú trống — không gọi AI');
      expect(luat('mua 2 ly trà sữa 60k').oThieu, isEmpty, reason: '"2 ly" là số lượng, không phải tiền');
    });

    test('thu/chi KHÔNG phải ô thiếu — câu không có từ chỉ thu vẫn không gọi AI', () {
      expect(luat('bún chả 45k').oThieu, isEmpty, reason: 'nhóm này không có danh mục nào — chỉ xét chiều');
    });

    // ĐỔI QUYẾT ĐỊNH lần nữa (người dùng 2026-09-30, sau lượt đo 3 thấy "mua 2 ly trà sữa 60k" trống danh mục): "tôi muốn
    // chỗ nào không điền được thì sẽ cho AI vào để điền mà" — danh mục trống cũng là ô thiếu.
    test('⭐ danh mục trống (câu còn chữ để đoán) là ô thiếu; AI lấp qua kiểm', () {
      final an = makeCategory(id: 'c-an', name: 'Ăn uống');
      KetQuaDocCau dm(String cau, {KetQuaAi? ai}) =>
          docCauGiaoDich(cau, now: now, vi: [tcb, chinh], chonDuoc: [an], ai: ai);
      expect(dm('mua 2 ly trà sữa 60k').oThieu, {OThieu.danhMuc});
      expect(dm('45k ăn uống').oThieu, isEmpty, reason: 'tên danh mục trong câu');
      expect(dm('45k').oThieu, isEmpty, reason: 'không còn chữ nào để đoán danh mục');
      expect(dm('chuyển 500k từ tiền mặt sang Techcombank').oThieu, isEmpty, reason: 'chuyển ví không có danh mục');
      final r = dm('mua 2 ly trà sữa 60k', ai: const KetQuaAi(danhMuc: 'Ăn uống'));
      expect(r.categoryId, 'c-an');
      expect(r.oThieu, isEmpty);
      expect(r.quaAi, isTrue);
    });

    test('⭐ ĐỔI QUYẾT ĐỊNH: luật đọc được số tiền thì LUẬT THẮNG, kể cả khi số AI là một cách đọc hợp lệ', () {
      expect(voiAi('đổ 2 lít xăng 50k', const KetQuaAi(soTien: 200000)).soTien, 50000,
          reason: '200.000 (2 lít) là cách đọc hợp lệ — bản "AI đọc mọi câu" để AI thắng');
      final r = voiAi('ăn sáng 30k, grab 50k', const KetQuaAi(soTien: 50000));
      expect(r.soTien, 30000);
      expect(r.canhBao, contains(kCanhBaoNhieuSoTien), reason: 'AI không lấp thì cảnh báo của luật ở lại');
    });

    test('⭐ ĐỔI QUYẾT ĐỊNH: luật đọc được chiều THU thì AI nói "chi" không đè', () {
      expect(voiAi('nhận lương 9tr', const KetQuaAi(loai: 'chi')).loai, 'thu');
    });

    test('ô thiếu tính SAU khi AI lấp: lấp được thì hết thiếu, AI bị chặn thì vẫn thiếu', () {
      expect(voiAi('cà phê với Nam mất ba chục', const KetQuaAi(soTien: 30000, ghiChu: 'cà phê với Nam')).oThieu, isEmpty);
      expect(voiAi('cà phê với Nam mất ba chục', const KetQuaAi(soTien: 30000)).oThieu, {OThieu.ghiChu},
          reason: 'AI lấp số tiền mà không dọn ghi chú — "mất ba chục" vẫn nằm đó');
      expect(voiAi('cà phê với Nam mất ba chục', const KetQuaAi(soTien: 300000)).oThieu, {OThieu.soTien, OThieu.ghiChu});
    });

    test('ghi chú khi AI lấp số tiền: ghi chú AI được dùng nếu chỉ BỚT chữ (người dùng chốt §8 câu 9)', () {
      expect(voiAi('cà phê với Nam mất ba chục', const KetQuaAi(soTien: 30000, ghiChu: 'cà phê với Nam')).ghiChu,
          'cà phê với Nam');
    });

    test('ngày: "đầu tháng" luật đọc được → không thiếu; AI tính lệch thì luật thắng (§8 câu 4)', () {
      expect(luat('đầu tháng đóng học phí 2tr').oThieu, isEmpty);
      expect(voiAi('đầu tháng đóng học phí 2tr', const KetQuaAi(ngay: '30/09/2026')).ngay, DateTime(2026, 9, 1),
          reason: 'Realme 2026-09-30: AI trả hôm nay cho "đầu tháng"');
    });

    test('⭐ ngày: chữ thời gian lẻ mang nghĩa khác và cụm chỉ KỲ không phải ngày thiếu — không gọi AI oan ~18 s', () {
      for (final c in [
        'vé tháng 2tr',
        'lương tháng 9tr',
        'đầu tư chứng khoán 5tr',
        'mua mấy thứ lặt vặt 200k',
        'tiền điện tháng này 450k',
        'tiền điện tháng 9 450k',
        'học phí năm nay 2tr',
      ]) {
        expect(luat(c).oThieu, isEmpty, reason: c);
      }
      for (final c in ['cuối tháng này đóng học 2tr', 'cuối tháng đóng tiền nhà 3tr']) {
        expect(luat(c).oThieu, isEmpty,
            reason: '$c — người dùng chọn 2026-10-06 bỏ chờ AI vô ích: Realme 2026-09-30 câu 11 gọi AI 14 s, AI trả hôm '
                'nay (lớp kiểm bỏ) — ngày cuối tháng này là hôm nay hoặc tương lai, AI không lấp được gì');
      }
    });

    test('ngày: câu chỉ nêu KỲ thì AI không được đổi ngày ("tiền điện tháng 9" không thành 01/09)', () {
      expect(voiAi('tiền điện tháng 9 450k', const KetQuaAi(ngay: '01/09/2026')).ngay, isNull);
    });

    test('⚠️ số của mốc lịch không phải tiền: "tháng 10", "ngày 15", "tháng mười" không đọc thành 10.000 / 15.000', () {
      for (final c in ['tiền điện tháng 10', 'đóng học ngày 15', 'tiền điện tháng mười']) {
        expect(cachDocSoTien(c, now: now), isEmpty, reason: c);
        expect(luat(c).oThieu, isNot(contains(OThieu.soTien)), reason: c);
      }
    });

    // Realme 2026-09-30 lượt 3: "quẹt thẻ ăn phở 45k" nhận ví Tiền mặt do AI chọn — lớp kiểm coi mọi chữ chỉ ví là "câu
    // nhắc ví" rồi nhận BẤT KỲ ví nào. Người dùng chốt: chữ chỉ thẻ / ngân hàng chỉ nhận ví ngân hàng.
    test('⭐ thẻ / quẹt / ck / chuyển khoản / atm chỉ nhận ví NGÂN HÀNG; chữ "ví" trần nhận mọi ví', () {
      expect(voiAi('quẹt thẻ ăn phở 45k', const KetQuaAi(vi: 'Tiền mặt')).walletId, isNull);
      expect(voiAi('quẹt thẻ ăn phở 45k', const KetQuaAi(vi: 'Techcombank')).walletId, 'w-tcb');
      expect(voiAi('ck 45k tiền nhà', const KetQuaAi(vi: 'Tiền mặt')).walletId, isNull);
      expect(voiAi('trả bằng ví 45k', const KetQuaAi(vi: 'Tiền mặt')).walletId, 'w-cash');
    });

    test('tài khoản KHÔNG có ví ngân hàng: "quẹt thẻ" không phải ví thiếu — điền ngay, không gọi AI', () {
      KetQuaDocCau chiTienMat(String cau) => docCauGiaoDich(cau, now: now, vi: [chinh], chonDuoc: const []);
      expect(chiTienMat('quẹt thẻ ăn phở 45k').oThieu, isEmpty);
      expect(chiTienMat('trả bằng ví 45k').oThieu, {OThieu.vi}, reason: '"ví" trần vẫn nhắc ví');
    });

    test('⚠️ so từng từ CÓ DẤU: "vì" không phải "ví", "thế" không phải "thẻ" — không gọi AI oan', () {
      expect(luat('vì đói nên ăn phở 45k').oThieu, isEmpty);
      expect(luat('như thế là hết 45k').oThieu, isEmpty);
      expect(luat('quet the an pho 45k').oThieu, {OThieu.vi}, reason: 'gõ không dấu vẫn nhận');
    });

    // Người dùng chốt 2026-09-30: dòng nguồn chỉ nói "Đọc bằng AI" khi AI làm ĐỔI một ô trên form (Realme lượt 3: câu
    // "cuối tháng" hiện "Đọc bằng AI" chỉ vì AI xác nhận chiều chi — mặc định của form).
    test('⭐ quaAi: AI xác nhận chiều / ví ĐANG CHỌN trên form không phải đổi ô', () {
      final r = voiAi('cuối tháng đóng tiền nhà 3tr', const KetQuaAi(loai: 'chi', ngay: '30/09/2026'));
      expect(r.loai, 'chi');
      expect(r.quaAi, isFalse, reason: 'form mặc định đã ở Chi tiêu');
      final thu = docCauGiaoDich('cuối tháng đóng tiền nhà 3tr',
          now: now, vi: [tcb, chinh], chonDuoc: const [], chieuDangChon: 'thu', ai: const KetQuaAi(loai: 'chi'));
      expect(thu.quaAi, isTrue, reason: 'form đang ở Thu nhập — AI kéo về Chi tiêu là đổi ô');
      final vi = docCauGiaoDich('trả bằng ví 45k',
          now: now, vi: [tcb, chinh], chonDuoc: const [], viDangChon: 'w-cash', ai: const KetQuaAi(vi: 'Tiền mặt'));
      expect(vi.walletId, 'w-cash');
      expect(vi.quaAi, isFalse, reason: 'ví AI chọn chính là ví đang chọn');
    });

    test('quaAi = AI THẬT SỰ lấp ít nhất một ô (dòng nguồn); AI bị chặn hết → "Đọc bằng luật"', () {
      expect(voiAi('ăn phở 45k', const KetQuaAi(soTien: 450000)).quaAi, isFalse);
      expect(voiAi('cà phê với Nam mất ba chục', const KetQuaAi(soTien: 30000)).quaAi, isTrue);
      expect(voiAi('hôm qua ăn phở với bạn 45k', const KetQuaAi(ghiChu: 'ăn phở')).quaAi, isTrue,
          reason: 'ghi chú của AI được dùng');
    });
  });

  // Người dùng báo 2026-09-30: câu chuyển giữa hai ví của mình bị đọc sai — "chuyển 500k từ tiền mặt sang tiết kiệm"
  // thành khoản CHI từ ví Tiết kiệm (luật lấy tên ví DÀI NHẤT làm ví nguồn, không ai đọc chữ "chuyển"). §2.9 spec.
  group('§2.9 chuyển ví', () {
    // Như tài khoản 10 trên Realme: hai ví tiền mặt, hai ví tiết kiệm có tên lồng nhau.
    final tienMat = makeWallet(id: 'w-tm', name: 'Tiền mặt');
    final test_ = makeWallet(id: 'w-test', name: 'test');
    final tietKiem = makeWallet(id: 'w-tk', name: 'Tiết kiệm').copyWith(type: 'saving');
    final muaNha = makeWallet(id: 'w-mn', name: 'tiết kiệm mua nhà').copyWith(type: 'saving');
    final tcb = makeWallet(id: 'w-tcb', name: 'Techcombank').copyWith(type: 'bank');
    final an = makeCategory(id: 'c-an', name: 'Ăn uống');
    final vi = [tienMat, test_, tietKiem, muaNha, tcb];
    KetQuaDocCau cv(String cau, {KetQuaAi? ai, List<Wallet>? dsVi}) =>
        docCauGiaoDich(cau, now: now, vi: dsVi ?? vi, chonDuoc: [an], ai: ai);

    test('⭐ "chuyển 500k từ tiền mặt sang tiết kiệm" → chuyển ví Tiền mặt → Tiết kiệm, không danh mục, ghi chú rỗng', () {
      final r = cv('chuyển 500k từ tiền mặt sang tiết kiệm');
      expect(r.loai, 'transfer');
      expect(r.soTien, 500000);
      expect(r.walletId, 'w-tm', reason: 'trước đây: ví Tiết kiệm (tên dài nhất) làm ví NGUỒN của một khoản chi');
      expect(r.walletToId, 'w-tk');
      expect(r.categoryId, isNull);
      expect(r.ghiChu, '');
      expect(r.oThieu, isEmpty);
    });

    test('chỉ nêu ví đích → nguồn null (form giữ ví đang chọn); tên dài thắng; phần còn lại là ghi chú', () {
      final r = cv('chuyển 2tr sang tiết kiệm mua nhà để mua xe');
      expect(r.loai, 'transfer');
      expect(r.walletToId, 'w-mn');
      expect(r.walletId, isNull);
      expect(r.ghiChu, 'để mua xe');
    });

    test('giới từ đích: vào / tới / đến, kể cả có chữ "ví"; không cần chữ "chuyển"', () {
      final nap = cv('nạp 100k vào Techcombank');
      expect(nap.loai, 'transfer');
      expect(nap.walletToId, 'w-tcb');
      expect(nap.ghiChu, 'nạp');
      expect(cv('chuyển 1tr tới ví Techcombank').walletToId, 'w-tcb');
      expect(cv('chuyển 1tr đến Techcombank').walletToId, 'w-tcb');
    });

    test('"chuyển … X qua Y": "qua" là đích khi có chữ "chuyển"; ví kia là nguồn', () {
      final r = cv('chuyển 500k tiền mặt qua tiết kiệm');
      expect(r.loai, 'transfer');
      expect(r.walletId, 'w-tm');
      expect(r.walletToId, 'w-tk');
      expect(r.ghiChu, '');
    });

    test('"chuyển" + đúng hai ví, không giới từ → trước là nguồn, sau là đích', () {
      final r = cv('chuyển tiền mặt tiết kiệm 500k');
      expect(r.walletId, 'w-tm');
      expect(r.walletToId, 'w-tk');
    });

    test('"tiền mặt" không phải tên ví nào → ví tiền mặt duy nhất làm nguồn', () {
      final chinh = makeWallet(id: 'w-chinh', name: 'Ví chính');
      final r = cv('chuyển 500k từ tiền mặt sang Techcombank', dsVi: [chinh, tcb]);
      expect(r.walletId, 'w-chinh');
      expect(r.walletToId, 'w-tcb');
    });

    test('⚠️ KHÔNG phải chuyển ví: không có ví đích — "chuyển khoản cho mẹ", "trả qua Techcombank", "ck qua Techcombank"', () {
      final ck = cv('chuyển khoản 500k cho mẹ');
      expect(ck.loai, isNull);
      expect(ck.walletToId, isNull);
      final qua = cv('trả tiền điện qua Techcombank 500k');
      expect(qua.loai, isNull);
      expect(qua.walletId, 'w-tcb', reason: '"qua" không kèm "chuyển" = trả BẰNG ví ấy');
      expect(qua.walletToId, isNull);
      final ckQua = cv('chuyển khoản qua Techcombank 500k cho mẹ');
      expect(ckQua.loai, isNull, reason: '"chuyển khoản qua X" = trả bằng X, không phải chuyển sang X');
      expect(ckQua.walletId, 'w-tcb');
    });

    test('nguồn trùng đích → bỏ nguồn (form giữ ví đang chọn)', () {
      final r = cv('chuyển 500k từ tiết kiệm sang tiết kiệm');
      expect(r.walletToId, 'w-tk');
      expect(r.walletId, isNull);
    });

    test('chữ "ví" của ví đích không làm ví nguồn thành ô thiếu', () {
      expect(cv('chuyển 500k sang ví tiết kiệm').oThieu, isEmpty);
    });

    test('dòng tóm tắt: "Chuyển ví" + nguồn → đích; chỉ có đích thì "sang …"', () {
      final r = cv('chuyển 500k từ tiền mặt sang tiết kiệm');
      expect(cauDaDien(r, tenVi: 'Tiền mặt', tenViDen: 'Tiết kiệm', now: now),
          'Đã điền: 500.000 đ · Chuyển ví · Tiền mặt → Tiết kiệm');
      expect(cauDaDien(cv('chuyển 2tr sang tiết kiệm'), tenViDen: 'Tiết kiệm', now: now),
          'Đã điền: 2.000.000 đ · Chuyển ví · sang Tiết kiệm');
    });

    group('AI (chỉ khi luật không đọc được chiều)', () {
      test('KetQuaAi.tuThamSo: "chuyen_vi" → transfer, vi_den → viDen', () {
        final a = KetQuaAi.tuThamSo({'loai': 'chuyen_vi', 'vi_den': 'Tiết kiệm'});
        expect(a.loai, 'transfer');
        expect(a.viDen, 'Tiết kiệm');
      });

      test('AI nói chuyển tới ví câu có nhắc (viết tắt) → chuyển ví; danh mục AI bị bỏ', () {
        final r = cv('chuyển ba chục qua techcom',
            ai: const KetQuaAi(soTien: 30000, loai: 'transfer', viDen: 'Techcombank', danhMuc: 'Ăn uống'));
        expect(r.loai, 'transfer');
        expect(r.walletToId, 'w-tcb');
        expect(r.soTien, 30000);
        expect(r.categoryId, isNull);
        expect(r.quaAi, isTrue);
      });

      test('⚠️ AI nói chuyển tới ví câu KHÔNG nhắc → bỏ; luật đọc được chiều → luật thắng; đích trùng nguồn → bỏ', () {
        final khongNhac = cv('cà phê mất ba chục', ai: const KetQuaAi(loai: 'transfer', viDen: 'Tiết kiệm'));
        expect(khongNhac.loai, isNull);
        expect(khongNhac.walletToId, isNull);
        expect(cv('nhận lương 9tr', ai: const KetQuaAi(loai: 'transfer', viDen: 'Tiết kiệm')).loai, 'thu');
        final trung = cv('quẹt thẻ techcom 45k',
            ai: const KetQuaAi(vi: 'Techcombank', loai: 'transfer', viDen: 'Techcombank'));
        expect(trung.walletId, 'w-tcb');
        expect(trung.loai, isNull);
        expect(trung.walletToId, isNull);
      });
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
