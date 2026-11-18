"""AI-proposed conversion of TabFormer to a Vietnamese setting: MCC -> FlowMoney expense category, and
income tiers that set each user's monthly spending level in VND.

Origin: proposed by Claude (Claude Code, model claude-opus-5-5) on 2026-11-10 at the authors' request. The MCC
descriptions are the model's recollection of the ISO 18245 / card-network MCC list and were NOT checked against
an official copy. Status stays DRAFT until both authors have rated the table on the 5-point Likert form
(likert_form.py); after that it is set to LOCKED and must not change.

The eight targets are the live default expense categories of FlowMoney (category table, Is_default = true,
Delete_at IS NULL, PersonFinance, read 2026-11-10). "Chi khác" exists but is soft-deleted, so codes with no
natural home were placed in the closest live category; the note says why.
"""
STATUS = "DRAFT"

CATEGORIES = ["Ăn uống", "Di chuyển", "Nhà cửa", "Hóa đơn", "Mua sắm", "Giải trí", "Giáo dục", "Y tế"]

# code: (description, category, note)
MCC = {
    4829: ("Money transfer / wire", "Nhà cửa", "Ở VN tiền nhà, tiền trọ thường trả bằng chuyển khoản; không có danh mục 'Chuyển tiền'"),
    5541: ("Service stations (fuel)", "Di chuyển", "Đổ xăng"),
    5411: ("Grocery stores, supermarkets", "Ăn uống", "Đi chợ, siêu thị thực phẩm"),
    5300: ("Wholesale clubs", "Mua sắm", ""),
    5499: ("Misc. food stores, convenience", "Ăn uống", "Cửa hàng tiện lợi"),
    5912: ("Drug stores, pharmacies", "Y tế", "Nhà thuốc"),
    4900: ("Utilities (electric, gas, water)", "Hóa đơn", "Điện, nước"),
    7538: ("Automotive service shops", "Di chuyển", "Sửa, bảo dưỡng xe"),
    5311: ("Department stores", "Mua sắm", ""),
    5812: ("Restaurants", "Ăn uống", ""),
    4784: ("Tolls and bridge fees", "Di chuyển", "Phí đường bộ, gửi xe"),
    4814: ("Telecommunication services", "Hóa đơn", "Điện thoại, internet"),
    4121: ("Taxicabs, limousines", "Di chuyển", "Taxi, xe công nghệ"),
    5814: ("Fast food restaurants", "Ăn uống", ""),
    6300: ("Insurance", "Hóa đơn", "Phí bảo hiểm định kỳ"),
    5310: ("Discount stores", "Mua sắm", ""),
    4111: ("Commuter transport", "Di chuyển", "Xe buýt, metro"),
    5211: ("Building materials", "Nhà cửa", ""),
    4899: ("Cable and pay TV", "Hóa đơn", "Truyền hình, gói nội dung"),
    4722: ("Travel agencies", "Giải trí", "Du lịch"),
    5813: ("Bars, taverns", "Ăn uống", "Quán nhậu, cà phê tính vào Ăn uống"),
    8021: ("Dentists", "Y tế", ""),
    7230: ("Beauty and barber shops", "Mua sắm", "Chăm sóc cá nhân; không có danh mục riêng"),
    7995: ("Betting, lottery", "Giải trí", ""),
    5942: ("Book stores", "Giáo dục", ""),
    8011: ("Doctors", "Y tế", ""),
    5719: ("Misc. home furnishings", "Nhà cửa", ""),
    5651: ("Family clothing stores", "Mua sắm", ""),
    7832: ("Motion picture theaters", "Giải trí", "Rạp phim"),
    8111: ("Legal services", "Hóa đơn", "Dịch vụ trả phí; không có danh mục riêng"),
    7922: ("Theatrical ticket agencies", "Giải trí", ""),
    7011: ("Hotels, motels", "Giải trí", "Lưu trú khi du lịch"),
    5970: ("Artist and craft supply", "Mua sắm", ""),
    8062: ("Hospitals", "Y tế", ""),
    7801: ("Online gambling (licensed)", "Giải trí", ""),
    7802: ("Horse / dog racing", "Giải trí", ""),
    8043: ("Opticians", "Y tế", "Kính mắt"),
    7349: ("Cleaning and maintenance", "Nhà cửa", "Dọn nhà"),
    4511: ("Airlines", "Di chuyển", ""),
    7996: ("Amusement parks", "Giải trí", ""),
    8099: ("Medical services n.e.c.", "Y tế", ""),
    8041: ("Chiropractors", "Y tế", ""),
    8049: ("Podiatrists", "Y tế", ""),
    9402: ("Postal services", "Hóa đơn", "Bưu điện, gửi hàng"),
    4214: ("Courier, freight", "Hóa đơn", "Phí giao hàng"),
    5251: ("Hardware stores", "Nhà cửa", ""),
    5921: ("Beer, wine, liquor stores", "Ăn uống", ""),
    5655: ("Sports apparel", "Mua sắm", ""),
    5712: ("Furniture stores", "Nhà cửa", ""),
    5932: ("Antique shops", "Mua sắm", ""),
    5661: ("Shoe stores", "Mua sắm", ""),
    5732: ("Electronics stores", "Mua sắm", ""),
    5815: ("Digital media (books, movies, music)", "Giải trí", "Gói xem phim, nghe nhạc"),
    5621: ("Women's clothing", "Mua sắm", ""),
    7276: ("Tax preparation", "Hóa đơn", ""),
    8931: ("Accounting services", "Hóa đơn", ""),
    7210: ("Laundry services", "Nhà cửa", "Giặt ủi"),
    4112: ("Passenger railways", "Di chuyển", "Tàu hoả"),
    7542: ("Car washes", "Di chuyển", "Rửa xe"),
    1711: ("Plumbing, heating contractors", "Nhà cửa", "Sửa điện nước"),
    5533: ("Auto parts stores", "Di chuyển", ""),
    7531: ("Auto body repair", "Di chuyển", ""),
    5816: ("Digital goods: games", "Giải trí", ""),
    5045: ("Computers and peripherals", "Mua sắm", ""),
    7549: ("Towing services", "Di chuyển", "Cứu hộ xe"),
    5192: ("Books, periodicals, newspapers", "Giáo dục", ""),
    7393: ("Security services", "Nhà cửa", ""),
    4411: ("Cruise lines", "Giải trí", ""),
    5261: ("Nurseries, garden supply", "Nhà cửa", ""),
    5193: ("Florists' supplies", "Mua sắm", ""),
    5094: ("Jewelry, precious stones", "Mua sắm", ""),
    4131: ("Bus lines", "Di chuyển", "Xe khách"),
    5722: ("Household appliance stores", "Nhà cửa", "Đồ gia dụng"),
    5733: ("Music stores", "Giải trí", ""),
    5977: ("Cosmetic stores", "Mua sắm", ""),
    5941: ("Sporting goods", "Mua sắm", ""),
    5947: ("Gift, card, novelty shops", "Mua sắm", ""),
}
# ISO 18245 ranges: 3000-3299 airlines, 3351-3441 car rental, 3501-3999 lodging.
for _c in (3000, 3001, 3005, 3006, 3007, 3008, 3009, 3058, 3066, 3075, 3132, 3144, 3174, 3256, 3260):
    MCC[_c] = ("Airline (named carrier)", "Di chuyển", "Vé máy bay")
for _c in (3359, 3387, 3389, 3390, 3393, 3395, 3405):
    MCC[_c] = ("Car rental (named company)", "Di chuyển", "Thuê xe")
for _c in (3504, 3509, 3596, 3640, 3684, 3722, 3730, 3771, 3775, 3780):
    MCC[_c] = ("Hotel (named chain)", "Giải trí", "Lưu trú khi du lịch")

# Income tiers. A user's tier comes from the rank of their median monthly card spending in TabFormer (the
# original level is kept as an ordering only). Within the tier, the target median monthly spending (VND) is
# placed log-uniformly by rank between lo and hi. Every amount is then multiplied by the user's own factor and
# rounded to the nearest 1,000 VND. Tier shares and bounds are assumptions, not survey statistics.
TIERS = [
    # (name, share of users, lo VND/month, hi VND/month)
    ("Sinh viên", 0.25, 3_000_000, 6_000_000),
    ("Mới đi làm", 0.35, 6_000_000, 12_000_000),
    ("Đi làm ổn định", 0.30, 12_000_000, 20_000_000),
    ("Thu nhập cao", 0.10, 20_000_000, 35_000_000),
]
ROUND_VND = 1_000
