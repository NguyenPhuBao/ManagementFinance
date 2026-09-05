/// Tiền tố ghi chú của giao dịch chi do luồng trả hoá đơn sinh ra.
///
/// Dùng chung cho nơi ghi (`BillRepositoryImpl.payBill`) và nơi nhận diện
/// (`transactionOwnerOf` — để sổ giao dịch không cho vuốt xoá rời khoản này,
/// vì trả hoá đơn là bốn bước trong một transaction và xoá một bước thì ba
/// bước kia còn nguyên). Chưa có cột `billId` cục bộ nên tiền tố là mối nối
/// duy nhất; người dùng tự gõ trùng tiền tố thì bị nhận nhầm — chấp nhận, vì
/// hậu quả chỉ là không vuốt xoá được.
const String kGhiChuTraHoaDon = 'Thanh toán hóa đơn: ';
