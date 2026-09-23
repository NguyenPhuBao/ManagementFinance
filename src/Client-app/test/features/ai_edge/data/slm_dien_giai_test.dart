// test/features/ai_edge/data/slm_dien_giai_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/data/slm_dien_giai.dart';
import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/data/slm_cache.dart';
import 'package:flowmoney/features/ai_edge/data/mo_hinh_tai_ve.dart';
import 'package:flowmoney/features/ai_edge/data/nguon_tai_nen.dart';
import 'package:flowmoney/features/ai_edge/data/phien_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';

class _RuntimeGia implements SlmRuntime {
  final String Function(String prompt) traLoi;
  int soLanSinh = 0;
  int soLanNap = 0;
  bool napHong;
  bool _san = false;

  _RuntimeGia(this.traLoi, {this.napHong = false});

  @override
  bool get dangSan => _san;
  @override
  Future<void> moHinhSan(String duongTep) async {
    soLanNap++;
    if (napHong) throw Exception('không nạp được');
    _san = true;
  }

  @override
  Future<String> sinh(String prompt, {int tranToken = 120}) async {
    soLanSinh++;
    return traLoi(prompt);
  }

  @override
  Stream<String> sinhDan(String prompt, {int tranToken = 300}) =>
      Stream.value(traLoi(prompt));

  @override
  Future<PhienCongCu> moPhien({
    required String heThong,
    required String cauHoi,
    required List<KhaiBaoCongCu> congCu,
  }) =>
      throw UnimplementedError('SlmDienGiai không mở phiên tool');

  @override
  Future<void> huy() async {}

  @override
  Future<void> dong() async => _san = false;
}

class _Goi implements GoiSo {
  @override
  final String man = 'ngan_sach';
  @override
  final List<SoLieu> soLieu = [soTien('Đã chi', 45000), soPhanTram('Tỉ lệ', 90)];

  /// Mức của hệ luật — `kiemGiong` đối chiếu câu với nó, nên ca "sai giọng"
  /// phải đặt được. Mặc định `binhThuong` để mọi ca cũ dựng không đổi.
  final MucNhanXet muc;
  _Goi([this.muc = MucNhanXet.binhThuong]);
  @override
  bool get thieuDuLieu => false;
  @override
  NhanXet mauCau() => NhanXet(
        cau: 'Câu mẫu 45.000 đ.',
        theSoLieu: soLieu,
        muc: muc,
      );
  @override
  String get dauVan => 'van-co-dinh';
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('sdg'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<SlmDienGiai> dung(_RuntimeGia rt, {bool coTep = true}) async {
    if (coTep) File('${tmp.path}/$kTenTep').writeAsBytesSync([1, 2, 3]);
    final cache = SlmCache(thuMuc: () async => tmp);
    await cache.nap();
    return SlmDienGiai(
      runtime: rt,
      cache: cache,
      // `coTepByte: 3` — `daCo()` nay kiểm kích thước, và tệp giả ở trên
      // dài đúng 3 byte.
      moHinh: MoHinhTaiVe(
        thuMuc: () async => tmp,
        nguon: NguonTaiNenGia(),
        coTepByte: 3,
      ),
    );
  }

  test('câu hợp lệ đi qua, gắn cờ tuMoHinh', () async {
    final rt = _RuntimeGia((_) => 'Đã chi 45.000 đ, tức 90,0%.');
    final nx = await (await dung(rt)).dienGiai(_Goi());
    expect(nx.cau, 'Đã chi 45.000 đ, tức 90,0%.');
    expect(nx.tuMoHinh, isTrue);
    expect(nx.theSoLieu, hasLength(2),
        reason: 'Thẻ số liệu luôn là của GÓI, không phải thứ mô hình trả về.');
  });

  test('⚠️ câu BỊA SỐ thì rơi về mẫu câu, không hiện ra', () async {
    final rt = _RuntimeGia((_) => 'Đã chi 99.999 đ, tức 12,3%.');
    final nx = await (await dung(rt)).dienGiai(_Goi());
    expect(nx.cau, 'Câu mẫu 45.000 đ.');
    expect(nx.tuMoHinh, isFalse,
        reason: 'Không gắn nhãn AI cho câu mẫu — nhãn ấy là lời hứa rằng câu '
            'do mô hình viết.');
  });

  test('⚠️ câu ĐỦ SỐ nhưng SAI GIỌNG thì rơi về mẫu câu', () async {
    // Gói ở mức cảnh báo; runtime giả trả một câu trấn an mang đúng mọi số —
    // `kiemSo` cho qua, `kiemGiong` phải chặn.
    final rt = _RuntimeGia((_) => 'Bạn đang kiểm soát tốt: đã dùng 90,0%.');
    final nx = await (await dung(rt)).dienGiai(_Goi(MucNhanXet.canhBao));
    expect(nx.tuMoHinh, isFalse, reason: 'sai giọng phải rơi về mẫu, không hiện');
    expect(nx.cau, 'Câu mẫu 45.000 đ.');
  });

  test('nạp hỏng (máy x86_64, RAM thấp) thì rơi về mẫu câu, KHÔNG ném',
      () async {
    final rt = _RuntimeGia((_) => 'không tới đây', napHong: true);
    final nx = await (await dung(rt)).dienGiai(_Goi());
    expect(nx.cau, 'Câu mẫu 45.000 đ.');
    expect(nx.tuMoHinh, isFalse);
  });

  test('chưa tải mô hình thì rơi về mẫu câu và KHÔNG thử nạp', () async {
    final rt = _RuntimeGia((_) => 'không tới đây');
    final nx = await (await dung(rt, coTep: false)).dienGiai(_Goi());
    expect(nx.cau, 'Câu mẫu 45.000 đ.');
    expect(rt.soLanNap, 0,
        reason: 'Nạp lười: người chưa tải mô hình không phải trả RAM nào.');
  });

  test('⚠️ gói số KHÔNG ĐỔI thì không gọi mô hình lần hai', () async {
    // Stream của mọi màn phát lại sau MỖI chu kỳ đồng bộ. Không cache thì mỗi
    // lượt phát là 2,3 giây chạy mô hình cho một gói y hệt — và câu nhấp nháy.
    final rt = _RuntimeGia((_) => 'Đã chi 45.000 đ, tức 90,0%.');
    final bo = await dung(rt);
    await bo.dienGiai(_Goi());
    await bo.dienGiai(_Goi());
    await bo.dienGiai(_Goi());
    expect(rt.soLanSinh, 1);
  });

  test('nạp mô hình đúng MỘT lần dù diễn giải nhiều gói', () async {
    final rt = _RuntimeGia((_) => 'Đã chi 45.000 đ, tức 90,0%.');
    final bo = await dung(rt);
    await bo.dienGiai(_Goi());
    await bo.dienGiai(_Goi());
    expect(rt.soLanNap, 1);
  });

  test('gói thiếu dữ liệu thì dùng mẫu câu, không gọi mô hình', () async {
    final rt = _RuntimeGia((_) => 'không tới đây');
    final bo = await dung(rt);
    await bo.dienGiai(_GoiThieu());
    expect(rt.soLanSinh, 0,
        reason: 'Nhánh thiếu dữ liệu là một câu THẬT đã chốt ở P2 — để mô hình '
            'diễn giải một gói rỗng là mời nó bịa.');
  });

  test('mô hình ném giữa chừng thì rơi về mẫu câu', () async {
    final rt = _RuntimeGia((_) => throw Exception('hết bộ nhớ'));
    final nx = await (await dung(rt)).dienGiai(_Goi());
    expect(nx.cau, 'Câu mẫu 45.000 đ.');
  });
}

class _GoiThieu implements GoiSo {
  @override
  final String man = 'ngan_sach';
  @override
  final List<SoLieu> soLieu = const [];
  @override
  bool get thieuDuLieu => true;
  @override
  NhanXet mauCau() => const NhanXet(
      cau: 'Chưa đủ dữ liệu.', theSoLieu: [], muc: MucNhanXet.thieuDuLieu);
  @override
  String get dauVan => 'van-thieu';
}
