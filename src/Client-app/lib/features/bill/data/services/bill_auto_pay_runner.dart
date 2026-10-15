import '../../../../core/database/app_database.dart';
import '../models/bill_entity.dart';
import '../repositories/bill_repository.dart';
import '../../domain/bill_auto_pay.dart';
import '../../domain/bill_ky_trung.dart';
import '../../../wallet/domain/wallet_status.dart';

/// Chạy các hoá đơn bật tự trả đã tới hạn.
///
/// Ở `data/services/` từ 2026-10-14 (bộ điều phối cầm `AppDatabase` — hàng mục 8 `KIEN_TRUC`).
///
/// ## Vì sao đi qua `payBill` chứ không tự ghi
///
/// Một lần trả phải làm đúng bốn việc trong một `db.transaction`: đánh dấu đã
/// trả, ghi khoản chi (mang `billId` để hoàn tác lần được), trừ ví, sinh kỳ
/// kế tiếp. Viết lại chuỗi ấy ở đây là tạo bản sao thứ hai của định nghĩa
/// "trả hoá đơn là gì", và bản sao sẽ lệch đi ở lần sửa sau.
///
/// ## Vì sao không có bộ lập lịch chạy nền
///
/// Nơi gọi là `NotificationScanner.scan()`, ngay sau `markOverdue`, cùng chỗ
/// với trích tiền mục tiêu. Kỳ bỏ lỡ được **trả bù** khi app mở lại, có trần.
/// Chuyển tiền luôn nằm trong tiến trình chính, dùng chung một kết nối CSDL.
///
/// ## Trả bù nhiều kỳ
///
/// Trả kỳ này xong, `payBill` sinh kỳ kế tiếp (nếu hoá đơn lặp). Kỳ ấy có thể
/// cũng đã quá hạn — sáu tháng không mở app — thì trả tiếp, tới trần
/// [toiDaMoiLuot] hoặc tới khi ví không đủ. Dừng **ngay** khi ví không cover
/// nổi kỳ kế tiếp: ba tháng tiền điện trả một lúc là rút cạn ví.
class BillAutoPayRunner {
  BillAutoPayRunner({
    required this.db,
    required this.repository,
    this.toiDaMoiLuot = tranKyTuTraMoiLuot,
  });

  final AppDatabase db;
  final BillRepository repository;

  /// Trần số kỳ xử lý cho MỖI hoá đơn trong một lượt chạy.
  final int toiDaMoiLuot;

  Future<List<BillAutoPayEvent>> chay(int idaccount, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final ra = <BillAutoPayEvent>[];

    // Chỉ những hoá đơn đến lượt TẠI LÚC ĐỌC. Kỳ kế tiếp sinh ra trong lượt
    // này được xử lý ở vòng `_chayMotChuoi` chứ không lọt vào danh sách này —
    // nếu không một chuỗi sẽ bị đếm hai lần.
    final denLuot = (await repository.getBills(idaccount))
        .where((b) => denLuotTuTra(b, at))
        .toList();

    // G87: kỳ có kỳ TRÙNG đã trả / bỏ qua thì bỏ qua IM LẶNG — lượt quét lúc mở app chạy trước khi kéo về nên máy có
    // thể giữ kỳ trùng ở "chưa trả". `payBill` cũng từ chối nó, nhưng để nó ném thì bộ chạy báo "không tự trả được".
    final tatCa = await repository.getAllIncludingDeleted(idaccount);
    denLuot.removeWhere((b) => kyCungKyDaDong(b, tatCa));

    for (final bill in denLuot) {
      // Mỗi hoá đơn độc lập: một cấu hình hỏng không được chặn những hoá đơn
      // còn lại, nếu không một lỗi lẻ làm cả tính năng ngừng chạy trong im
      // lặng.
      ra.addAll(await _chayMotChuoi(bill, idaccount, at));
    }

    return ra;
  }

  Future<List<BillAutoPayEvent>> _chayMotChuoi(
    BillEntity dau,
    int idaccount,
    DateTime at,
  ) async {
    final ra = <BillAutoPayEvent>[];
    BillEntity? bill = dau;

    while (bill != null && ra.length < toiDaMoiLuot) {
      // Ví không có khoá ngoại nên có thể đã bị xoá sau khi tạo hoá đơn. Kiểm
      // ở đây, không tin cột.
      // Ví ĐÃ LƯU TRỮ đi chung nhánh: lưu trữ là đóng băng ví — không sinh kỳ
      // mới, không tự rút tiền. Tên ví vẫn gửi kèm khi còn đọc được, để dòng
      // thông báo nói được ví nào.
      final vi = await db.walletDao.getById(bill.walletId!);
      if (vi == null || !WalletStatus.laHoatDong(vi.status)) {
        ra.add(_suKien(bill, LoaiTuTra.khongChayDuoc, 0, vi?.name));
        break;
      }

      final quyetDinh = quyetDinhTuTra(soTien: bill.amount, soDuVi: vi.balance);
      if (quyetDinh.loai != LoaiTuTra.traDu) {
        // DỪNG, và KHÔNG đổi gì: kỳ vẫn mở nên lượt sau tự thử lại khi ví có
        // tiền. Không sang kỳ sau — kỳ sau chỉ tồn tại khi kỳ này đã trả.
        ra.add(_suKien(bill, quyetDinh.loai, 0, vi.name));
        break;
      }

      try {
        await repository.payBill(
          bill: bill,
          walletId: bill.walletId!,
          idaccount: idaccount,
          amount: bill.amount,
          // Ngày của KỲ, không phải lúc bù: ba kỳ bù là ba sự việc của ba
          // ngày, không phải một cột dựng đứng ở ngày mở app. `payBill` chặn
          // giá trị ở tương lai, mà kỳ đến lượt thì hạn không ở tương lai.
          occurredAt: bill.dueDate,
        );
      } catch (_) {
        // `payBill` là một khối nguyên tử — hỏng thì không để lại gì. Nuốt
        // lỗi vì nơi gọi là vòng quét thông báo: ném lên là giết luôn trung
        // tâm thông báo, tức mất phần vẫn còn dùng được.
        ra.add(_suKien(bill, LoaiTuTra.khongChayDuoc, 0, vi.name));
        break;
      }

      ra.add(_suKien(bill, LoaiTuTra.traDu, quyetDinh.soTien, vi.name));

      // Kỳ kế tiếp vừa sinh ra — nếu nó cũng đã tới hạn thì trả tiếp.
      final kySau = await db.billDao.getGeneratedFrom(bill.id);
      bill = (kySau != null && denLuotTuTra(BillEntity.fromDrift(kySau), at)) ? BillEntity.fromDrift(kySau) : null;
    }

    return ra;
  }

  BillAutoPayEvent _suKien(
    BillEntity bill,
    LoaiTuTra loai,
    double soTien,
    String? tenVi,
  ) =>
      BillAutoPayEvent(
        billId: bill.id,
        billName: bill.name,
        ky: bill.dueDate,
        loai: loai,
        soTien: soTien,
        tenVi: tenVi,
      );
}
