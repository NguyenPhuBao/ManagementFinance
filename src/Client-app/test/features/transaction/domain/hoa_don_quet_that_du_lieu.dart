/// Chữ OCR THẬT của 16 hoá đơn đi qua `/quet` trên Realme RMX2205 (2026-10-21, bản debug `b174b8d6…`): trình chọn
/// ảnh → `image_picker` (nén lại ảnh) → ML Kit → `ghepDongTheoHang` — chép nguyên văn từ dòng `[Quet][OCR]` của logcat
/// (`print`, không bị tiết lưu; hai lượt quét lại R06 / R16 trùng từng byte). Số điện thoại / tên khách đã che như
/// `hoa_don_that_du_lieu.dart`.
///
/// Cùng 15 tờ R01–R16 với `hoa_don_that_du_lieu.dart` (ảnh rộng 1280 của buổi 08/10), nhưng chữ KHÁC: tệp ấy đọc bằng màn
/// spike, còn ở đây ảnh đã qua `image_picker` (R08 98.970 → 83.192 byte). Đây mới là đầu vào thật của `/quet` — G101.
/// Dữ liệu cho `hoa_don_quet_that_test.dart`; bảng kết quả ở mục 7 `docs/QUET_ANH_FEATURE.md`. Thêm 2026-10-22 tối: `N01b`
/// — tờ N01 chụp lại bằng máy ảnh (bản `16b71a1e…`), ảnh dính chữ lạ ở mép trên (G105); 17 mục.
library;

const Map<String, String> kHoaDonQuetRealme = {
  // ỦA TEA (398.800) — hoá đơn giấy MỚI, chụp dọc bằng máy ảnh
  'N01': r'''
ỦA TEA
Dia chl Kios 01. quang trung Dramond, Dnh Thi
Van phúc
Hotline: 0934B03456
HÓA ĐƠN THANH TOẢN
So HÐ: UAO06B
Må HÐ: #TH8HW TN: THUNGAN
Bàn: HUB (GRABFOOD) Ngày: 14/10/2026
(GF-264_TH8HW) Giò ra: 1407
Giò vào: 1407
STT Ten món SL Don Thanh
giá tien
MATCHA OATMILK 1 42,000 42,000
SIZE M
100% NGOT 1
100% ĐẢ 1
SÜA TƯCH TRẢN
2 CHÅU ĐuỜNG ĐEN-L 39,000| 39,000
50% NGOT
100% ĐẢ
MATCHA LATTE 1|39,000 39,000
SIZE M 1
50% ĐẢ
MATCHA LATTE 139,00o 39,000|
4gr bột Matcha 1 12,000 12,000|
SIZE M
MATCHA LATTE 139,900 39,000
-SIZE M
50% NG0T 0
TRA NHO XANH
THACH DỪA- L 245,000 90,000
NHÂN DỪA SỬA 149,000| 49,000
TRA TRẢI CẢY NHIET
ĐỞI -L 145,090 45,000
HÖP TRAI CÂY NHỞ
MIX 3 LOAI 129,000 29,000
Tóng sô món. 10
Thành tiên: 423,000
Tien chiết khẫu 24,200 d
Tổng tien: 398,800 d
+Thanh toán (GRAB_ONLINE) 398,800 d
Ghi chú: (GRABFOOD-GF-264_TH8HW-DELI-2026-
10-14 1407.30) . Hoa đon áp dụng bản hàng theo
kenh
Khách hang' - 8490000000
null
MRrealme Shot onE3Pro 5,6don hàng, quy khách vuị 2026 10 21 13:49
lò 1g liên hệ hotline nhé''',
  // ỦA TEA N01 chụp LẠI 2026-10-22 19:58 (Realme, bản `16b71a1e…`) — ảnh dính chữ lạ ở mép trên: OCR dòng đầu *"card n"*,
  // tên cửa hàng xuống dòng 3 kèm đuôi rác *"2DEE"* — G105.
  'N01b': r'''
card n
Dịa chi Kios 01, quang truờng Dramond, Drh Thi
ỦA TEA 2DEE
Thi, Van phúc
Hotline: 0934803456
HÒA ĐƠN THANH TOÁN
So HÐ: UAO068
Mã HD: #TH8HW TN: THU NGAN
an: HUB (GRABF00D) Ngðy: 14/10/2026
(GF-264_TH8HW)
Giò ra 1407
Gid vào: 1407
STT pon Thanh
Tên món
gid tien
MATCHA OATMILK 142,000 42,000
SIZE NM
100% NGOT 1
100% ĐẢ
SÜA TƯƠI TRẢN
CHÅU ĐUỜNG ĐẾN- L 39,000 39,000
50X NGOT
100% ĐẢ
MATCHA LATTE 39,000 39 000
-SIZE M
50% ĐẢ
4 MATCHA LATTE 39, 000 39,000
4gr bột Matcha 12,000 12,000|
- SIZE M 0
MATCHA LATTE 39,000| 39,000
- SIZE M
50% NGỘT
TRA NHO XANH
45,000 90,000
THACH DUA - L
NHẢN DỦA SỬA 149 000 49,000|
TRA TRÁI CAY NHHẾT
8 ĐỚI - L 145,0D0 45,000
HOP TRAI CẢY NHO
|MIX 3 LOAI 29,000 29,000
Tống số mon. i0
Thành tien: 423,000 d
Tien chiết khấu: 24,200 d
Töng tien: 398,800d
+Thanh toán (GRAB_ONLINE) 398,800 d
Ghi chú: (GRABFOOD-GF-264.THEHW-DEL-2026-
10 14 1407 30). Hoa đon áp dung bản hàng thea
kénh
Khách bông - 8490000000 -
null
Moi thác Inåc, khiéu nại dưn hàng, quy kihách vui
là ng lién hệ hotline nhé
MR realme Shot on O3 Pro 5G 2026 10 22 19:57
Cảm on Quy Khách
Powered by iPOs.vn''',
  // Starbucks
  'R01': r'''
STARBUCKS"
DELIVERS
04232-SENSE CITY
Sense City, 240-242 Kha Van Can,
Hiep Binh Ward, HCMC
(84) 28 3636 6959
Order number 8100030282 Sep 28, 2026 2:19PM
1 Mon Nuoc V Iced Pure Matcha Tea Latte
116,000
>1 Mon Nuoc Replace 0atmilk 5,000
>1 Mon Nuoc Nuoc No Sweet
>1 Mon Nuoc Extra AD Sauce 10k 10,000
1 Mon Nuoc V Iced Pure Matcha Tea Latte
116,000
>1 Mon Nuoc Replace Oatmi lk 5,000
>1 Mon Nuoc Less Sweet
>1 Mon Nuoc Extra AD Sauce 10k 10,000
262,000
Total
262,000
GrabFood
GF-714
Change Due
Vui long yeu cau Xuat hoa don GTGT ngay
khi giao dich truo0c khi hoan tat thanh toan.
Cac yeu cau xuat hoa don GTGT sau khi hoan
tat giao dich se khong the thuc hien.
Please request the VAT invoice at the time
of purchase. Ariy request of VAT invoice after
the purchase completed will not be served.
Thank you.
HR realme Shot on 03 Pro 5G 2026 10 02 08:15''',
  // ỦA TEA (158.000)
  'R02': r'''
ỦA TEA
Địa chí. Kios 01, quảng trường Diamond, Dinh Thi
Thi, Van phủc
Hotline: 0934803456
HÓA ĐƠN THANH TOẢN
1!
2@ Số HÐ: UA0082
F1
F2
Mã HD: #SRF5X TN: THU NGAN
(SPF-0793_SRF5X) Bàn: HUB (ShopeeFood) Giờ ra: 14.26 Ngày: 02/10/2026 7& 8
Giò vào::1426 F7 F8
Don Thành
|STT Ten mon SL giá tlèn
HÔNG TRÀ SỮA 39,000| 39,000 U
TRẢN CHÀU ĐEN- L
A
50% NGOT
-ĐẢ RIẾNG 1
2 Nui måm cay- 50gr 1|10,000 10,000
3 CAFE COco CLOUD( 1 39,000 39,000 J K
nưóc dừa foam cafe)
- 50% NGOT
-100% ĐẢ 0
Win 4 TRÀ LỰU EĐỎ -L 2|35,000 70,000 S
Alt 50% NGỌT 2
100% ĐÁ 2
Töng số nán: 5
Thành tiên: 158,000 d
Tống tiên: 158,000d
+Thanh toán (SHOPPEFOOD) 158,000d
Ghi chú: (SHOPEEF0OD-SPF-0798_SRF5X-DELI-
2026-10-02 14:26:29] Hóa đơn ảp dụng bán hàng
theo kênh
Khách hàng: - 84900000000 -
nul
Moi thắc mắc, khiếu nại đơn hàng, quỷ khách vui
lòng liên hệ hotline nhệ
Cảm on Quý Khách
Powered by iPOS.vn
A realme Shot on Q3 Pro 5G 2026 10 02 14:46''',
  // ỦA TEA (217.500)
  'R03': r'''
ASUS Vivobook
ỦA TEA
Địa chl: Kios 01, quảng trường Diamond, Dinh Thi
Thi, Vạn phủc
Hotline: 0934803456
HÓA ĐƠN THANH TOÁN
F1O So HÐ: UAO084
F8
Mã HÐ: #SRG1Y TN: THU NGÀN +
Bàn: HUB (ShopeeFood) Ngày: 02/10/2026
(SPF.0686_SRG1Y) Giờ ra: 14.33
Giờ vào:: 1433
Don glá Thành 7 9
STT Tên món SL tiền
PgUp
U 1 NHẦN KEM SỮA CAFE PHINDI HANH 133,000 33,000 Home
SIZE M
OLONG SÜA XOÀI -L|143,000| 43,000| 5
K 100% NGỌT 1
100% ĐÁ 1
3 TRÀ LỰU ĐỦ -L 1|35,000| 35,000
50% NGT 1 3
1
M 50% ĐẢ End PgDn
TRÀ LỰU ĐỎ -L 135,000| 35,000
100% NGọT
- ĐẢ RIẾNG Enter
Alt 5 TRA TRÁI CẢY NHIỆT 145,000 45,000 Insert Delete
ĐỚI- L.
-100% NGỌT 1
6 MATCHA LATTE 145,000| 45,000
SIZEL 1 10,000 10,000 Myh SonicMaster
Tõng số món: 6
Thành tièn: 246,000 d
Tiên chiết khảu -28,500 d
Tong tiên: 217,500 d
+Thanh toán (SHOPPEFOOD) 217,500 đ
Ghi chú: (SHOPEEF00D-SPF-9686_SRG1Y-DELE
2026-10-02 14:33.25|. Hoa don ap dung bản hàng
theo kênh
Khách hang - 84900000000-
null
Mọi thắc màc, khiếu nại dan hàng. quý khách vuị
long lên hệ hotline nhe
Cám ơn Quý Khách
Powered by iPOS.vn
realme Shot on žQ3 Pro 5G 2026 10 02 14:58''',
  // Bách Hoá Xanh (55.500)
  'R04': r'''
DHIẾU TRANH TOẢN BÁCH HÓA XANH
OV130393609036281
06/09/2326 18:29- V:215224
Giá bán (VAT) Thành tiễn
tiêu đen xay dh foods 45g*48
27.500 (VAT: 8%) 27.500
táo gala mini tui 800qr
S6 900 28.000 (VAT:5%) 28.000
55.500
Tbng tiền:
Chayka khokn (Tibt kiệm: 28.000a) 55.500
KH mua tel si8u thị và thanh toán tiện mat, yÔ tiàn 10 duoi
7004 dugc làm tròn xubng.trên 700d lam tròn len.
Quý khéoh in bla ac 6 vaT tựi bddt.bech.toaxaab, ooa, MẸ tra cui 8x410363
D VAT Chi xult trong ngdy. Gp ģ1 18001067 (miln phi)
ehhoaKAnb.on
Caa a qug khd ah đa dang chi nb ch d 1141 cA nhan tạ11 n Di
CÁM ƠN QuỸ KHÁCH ĐÃ CHOH BÁCH HOẢ ANE
MUA SAM TIỂT KIỆM MOI NGAY!
Hóa đon tích điem cho SĐT *****276 sau 24h.''',
  // eco-shop
  'R05': r'''
eco-shop Invoice
DONG MART (V69.VTA) MST. 0318641693
326 Lé Van iKhuong, Thoi An, Cuạn 12, Thanh phỏ Hó Chi Minh
Só HD # 121023427
Ngay 30/08/2026 21 33 37 Nguyen Van A
Hang hóa Thanh tien
F6
6406840019-Bột giat Robot 600g-8 00 19.000
3223840038-3C KTYT FAMAPRO 3 19,00u Fi1
80150132-Loạt do choi bong bu 19 000
Töng cộng 57.000
Tông cộng bao gôm VAT 5 57.000
EWallet(VNPAY OR) 67000 00
TRID SPOS26974781
Y VATbanto tat
Thué suat fièn hang Tiên thué
VAT-S5 ( 6% 36.190 1810
VAT-S 8 8% 17.693 1.407
O Quy ktach uon Kuât Hoa đon VAT.
H thuc hện
1 Quer má àR bên trai tim don hang
2 Nhap thông tin Auat hóa don truớc
23 gio cung ngay mua hàng
Hoa do đuoc gn theo enail dà nhàp
Cháp nhan doi harig trorg vong 24 gio
Sau khi đã nhập thông tn, Quy khach
có thê quét må OR bên phải dẻ ra cuu,
download hóa đon''',
  // Pharmacity
  'R06': r'''
NHÀ THUỐc
Pharmacity
ĐÚNG THUÖC -TÂN TẢM- TRÒN CHÜ TỈN
49 Pharn Xich tog Pralcha 3, Quên Phủ Nhuận VT
biện thoai:(028) 300-3350 Ext 1459
Xin chao. Chi A pg dn
Go ld
haitg thanh viên: 2, 144
Tong P-xu Bông hiện tại:
Thu ngân: lam Ho Đon giả Khuyến nại 20/08/2026 16:43 Thânh Tiên
Tên Si
000035 THUỜC CAT LIAU GNTT
42,000
6
MICLACOL BLUE - F
Ngày het han:12/11/2028
Vien 12 1,854 22,368
CHOPHY TOL ARTICHOKE
Ngày het hạn: 10/11/2026
Vien 12 1,042 12,504
Töng 30 sản phấn
Tông Tian 76,872
paus
S tiản thanh toán 76,872
Phuong thưc thanh toan: enter
T1êrn mạt 76,872
NHẬN MÃ GIÀM GIÁ 20,000D
KHI GIỚI THIỆU BẠN MỚI
Bố
intel
Cachh 1: Ct ia sé toi bạn tbe mã dR tal Ung duno RIS
Cácn 2: Mai bạ) bè rhập mả giởi thiệu
kEFKO15599510 khi dang ký thảnh viên
Liêrn hệ Dioc sĩ dể biết thêm Vẽ chường trình,
Co 9ia iri xuất h0a đơn GiGT trong ngày
1 P-xu BĐang tucng dương 1vnd
Chi tiet vë chuơng trinh khách h hàng thànih
ylérı xen ại Ứng dụng/Website Pharmacity
HOLiine dich vụ KH: 18006821 (nien phi)''',
  // MAXIDI (44.700)
  'R07': r'''
SL Muc Chc winh Phát, Quận 12, HCM Töng
Giá
10 Trung gà 2,000 20,000 V05
1 Snack To 5,000 5,000 VO8
Snack Kh 5,000 5,000 VO8
Cã phệ p 4,900 14,700 VO8
15 Töng 44,700
QR PAY VND 44,700
Đã bao göm thuế:
vO5 5 % 20,000 952
) VO8 8 % 24,700 i,830
Insert
Ngày Gid CH POS Tên Số GD
9/21/2026 18:55 2066 6 01 19039
Nguyên tắc làm tròn tiân: Delet
<500d lâm tròn xuöng 04
>=5004 làm tròn thành 1.0004
Neu quý khách có phàn nàn hoặc khen ngợi
vui lông truy cập khaosat.maxidi.vn
Biên lại tính tiên chi có giá tri
Xuất hủa dơn GTGT trong ngày.''',
  // MAXIDI (75.700) — G101: OCR đọc dòng tổng "75,706"
  'R08': r'''
tel
MAXIDI ORE
LUON RË NHAT
KHÔNG CO ĐỘI THỦ
Che Mirtof Uar 12. HCN
MoC
H,900 VO8
N Siuka 11,900 5,000 5,000 VO8
Snack bố 9,500 V08
9,500
Xà bong 6.900 V08
Phe Bò V Bun ga 7,500 7,500 VO6
24.906 24.900 VO8
F1
Kem 4500 4,500 VO8
1 Kem dưa 5,500 5,509 V08
Teng 75,706
Tiến mật 500,000
Tiên mật (Hiân) VNO 424,300 PgUp
Đã bao gðm thuế:
VO8 8 % 75,700 5,607
Ngày Gid CH POS Tên Số GD Pg Dn
9/11/2026 19:42 2066 4 02 1286
Nguyên tảc lat tron tiên:
<5004 làn trôn xuống 0d
>=5008 là tròn thảnh 1.000d
Shif
Neu quý ktiách có phàn nàn hoàc khern ngợi
vui lông truy cập khaosat.maxidi.vn
Biên lai tinh tign chỉ có giá trị
xuất hóa đon GTGT trong ngày.''',
  // quán trà (45.000)
  'R10': r'''
14 Feb
125/48/2 Lê Đuc Iho, Gò Váp
SÐT: 0979833492
BIẾN LAI
22082449 Ins
Số biên lai:
Dùng tại quán
Loat:
Phục vụ tbỏi: popi
19-09-2026 18:06
Thời gian:
Dele
Mặt hàng Đơn SL Giá số tiền
1. Trà vải khúc bạch 1 45,000 45,000
(Giá niêm yế)
Tống 45,000
Tổng 45,000d
ATM 45,000d
Pass wifr: hinihahahehe
Powered by Ocha''',
  // Bách Hoá Xanh nhoè mực (79.243)
  'R11': r'''
PHIỀU THANH TOÁN BẢCH HÔA XANH
88 ct Ov230393608037369
29/08/R326 1e137 - SV199184
GL bán (VAT) Thảnh tiển
SL
dua hầu đở
t.090 6.300 (VAT:5%) 16.588
2, 532
khoai tây
D,338 221.2S0 (VAT:5%} 3.802 acks
bi xarnti
0,356G6A 10.000 (VA":5%) 3.580
bông c6 enh nk (kg)
0,772 4026.009 (VAT:5%) 20.072
téo gala aini túi 800gr
49B 35.200 (VAT:5%) 35.200
79.243
Tong tien:
Chuyếs kkoas (T1ết *r: 52 84 24; 79.243
CAN N QUÝ KHÁCOH ĐÃ CHQN BACH HOẢ XANH
MUA SAM TIẾT KIM MOI NGÀYI
Hba đoH tich m cha hT ****9685 sau 24h.
Ctrl''',
  // Dookki
  'R12': r'''
DOOKKI Topokki Buftet
Korean
114-16 Ngvển Arh Ths dp rhànt, ován 12
Webit: wvw.dokki.cu.kr
HOA ĐON
Table: Trêt - 25 Bil No: 205219
(Trèt) Time in: 7:43
Time out: 20:52
Taies 30rD8/2026- 17.43 HGAN QUAN 1 PrtScn
Jterns Qty Price Totai
Buffet Người Lởn 2 139,000
278,000
SubTotal: 278,000
Total: 278,000
L VAT 8%: 22,240
Payment Ainount: 300,24O
Grab: 300,240
Customer: Kháct: tang ê
Alt
Ctrl''',
  // MAXIDI (72.127) — G101: OCR mất chữ 7 ở dòng tổng "2,127"; ngày đọc "912/2025"
  'R13': r'''
M
CORE
MAXIDI
LUÔN RẺ NHẤT
KIÓNG cÓ ĐỘITHỦ
uận 12, HCM
Töng
SL Muc
5900 VO8
Bột chie 19,800 VO5
Trang ga 15,990 V05
FIO F1 J.410 5.537 VO5
0.330 6,500 VO8
Kho gả l 2,400 VO8
4,000 VO8 Home PgUp
2 Trả Chan
6,000 V08
Trà tào
2,127
21 Tong
VNO72,121 End Pg
CR FAY
P
bã bao ga thue: 5% 45,127 2, 158
26,800 1,985
| 912/2025 13:28 2066 2 02 Ngày Gid CH FOS Tên S6 GD 5444
Nguyên tác làm trôn tiên:
<5004 làs tron xuông 0d
>=5000 làn tron thành 1.0004
Nêu quý khach có han nản tuac khen ngợi
Alt
Vui löng truy cặp khaosat.Biaxidi.vn
Bien lai tigh tin ch có gla tr
Xuat hoa ddn Gl6T 1rong ngy''',
  // MAXIDI (44.745)
  'R14': r'''
C
Chợ Minh Phát, Quận 12, HCM
SL Myc
Giá Töng
1 Mì Omach
11,500 11,500 O8
2 Cháo gà 3,100 6,200 V08
Mi Hảo H 4,000 8,000 Vo8
1 Snack To 5,000 5,000 Vo8
1 Dda Leo 16,500 2,145 VO5
0.130
1 Bánh Su 11,900 11,900 V08
8 Tông 44,745
QR PAY VND 44,745
Đã bao gôm thuế:
VOE 5 % 2,145 102 Hor
VOB 8 % 42,600 3,156
Ngày Gid CH POS Tên Số GD
10/1/2026 20:02 2066 6 01 23353
En
Nguyên tảc làm tròn tiến:
<500d låm tròn xuống 0đ
>=500d låm trn thành 1.0004
Néu quý khách có phàn nàn hoặc khen ngợi
Vui lông truy cập khaosat.max idi.vn
Biên lai tinh tiến chi có giá tri
Xuất hóa đơn GTGT trong ngày.''',
  // Bách Hoá Xanh trừ điểm (32.160 / thực trả 30.000)
  'R15': r'''
el IRIS
CORe
CHTAU THANH OAN BACP HÓA KATL
B8 ot: CVi03215608483425
8 o8, 2 b2 192R2N: 290495
GiA bán (VAT) Tành tiếr
Si
Scn
bắp cả1 tim (ky)
9e-r906 15.000 S.160
0,344 (VAT:5)
mi tr§n ili ket huOrg vi carhonara xbi
117g 13.500 (VAT:8%! 13.500
1
mì trện niliket huong vị chuá cay cianh
goi 11 7g 13.500 (VAT:8%) 13.500
1
quả tặng: phiAu mua hảng 15.000d mua
sta - thúc ubag bổ duờcg cấc loài tì
150.00 Oá (tr süa thủ ng)
32.160
Tông tiBn:
2.160
aiém sü dịng:
thuyén khd (iét iện: 7.320d) 30.000
CAM ON QUY KHACH BA CHON BACH HCA XANH
MUA SAM IỆT KIỆM NOI NGÀYI
Hoà đon ich diển cho Sp ****k*9685 sau 24h.
Ctrl''',
  // Bee Bee Mart
  'R16': r'''
tel
CORe
BEE BEE MART 18K
Địa Chi 527D Phan Vän Tri, Phưong 5, 0.Go Vap
SDT: 0344 528 929
HÓA DON BÁN HÀNG
Sô HÐ: HD162926
Ngày 19 thảng 09 nåm 2026/ 21:29
Khach hang Khàch lé
SÐT:
Địa chỉ. -.
F1 Đơn giá SL Thành tien
Ly thuý tinh lun uông trà,nuớc
18,000 36,000
Tong tiên hàng: 36,000 Home
Chiết khấu 0.00%:
Tong thanh toán: 36,000
Tien khách dua: 36,000
Tien thra trả khách: Enc
(Ba muoi sáu nghin đông chãn)
?
pIẾM 0
Cảm on và hẹn gäp ai!
Powered by KIOTVIET.''',
};
