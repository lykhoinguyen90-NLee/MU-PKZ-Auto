# MU-PKZ Auto Hunt / Combo

Source AutoHotkey v1.1 (Unicode 32-bit) dành cho Visual Studio Code. Bản này đồng bộ các macro trong thư mục `Macro`, chạy combo theo từng cửa sổ `Engine.exe`, và giữ tốc độ mặc định ở mức Jitbit Macro Recorder Fast/MAX.

## Build nhanh

1. Cài AutoHotkey v1.1 có `Ahk2Exe` và bộ nền `Unicode 32-bit.bin`.
2. Mở nguyên thư mục này bằng Visual Studio Code.
3. Bấm `Ctrl+Shift+B`, chọn `Build MU-PKZ AutoHunt`.
4. File hoàn chỉnh nằm tại `dist/MU-PKZ_AutoHunt.exe`.

Cũng có thể chạy trực tiếp:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

Script build tự kiểm tra cú pháp, kiểm tra toàn bộ profile nhúng và in SHA-256 của EXE.

## Macro đang được ánh xạ

| Profile | File nguồn |
|---|---|
| DW | `DW - Combo CotLua_MuaDoc_MuaBangTuyet_Speed1500.mcr` và logic bổ sung từ file `.ahk` cùng tên |
| DK | `DK Combo 3Sk_CN.DG.XK_HP.Q.E_Speed 2000.mcr` |
| DK V1 | `V1. DK Combo Chuẩn 3SKILL_ChemBang_Speed 2000.mcr` |
| ELF | `ELF V2 Combo 3Skill_3Tien_5Tien_TenBang_Speed1700.mcr` |
| RF | `RF Combo chuan 3sk ML.VN.GT_Speed 1000.mcr` |
| SUM | `Test. Skill combo + Bom Mau _SUM_Speed1000.mcr` |
| DL | `DL Skill combo chuan DL_Xich.HL.HoaDiem_DamNguaSpeed1500.mcr` |
| MG | `MG Combo 4Sk_HP.Q.E.Speed 1500.mcr` |

`AUTO HP` là tiện ích riêng, không phải file macro class. Hai biến thể DK đều có trong danh sách chọn.

## Tốc độ

- Mặc định: `286%`.
- Đây là mức Jitbit Fast/MAX: hệ số delay xấp xỉ `1.3^(1-5) = 0.350127`, tương đương `285.61%` và được làm tròn thành `286%`.
- Delay dưới 30 ms được giữ nguyên giống cách Jitbit bảo toàn cạnh nhấn/nhả phím.
- Thanh chỉnh vẫn cho phép tinh chỉnh riêng từng class và lưu vào Registry của người dùng.
- Lần chạy đầu của revision macro mới sẽ đưa các class về `286%` đúng một lần; các chỉnh sửa sau đó vẫn được giữ nguyên.

## Cách chạy

- `Ctrl+F1`: bật/tắt săn boss cho nhóm tài khoản đã tick.
- `Ctrl+F2`: bật/tắt combo cho nhân vật đã chọn.
- EXE chạy độc lập: nếu không có thư mục `Macro` bên cạnh, nó dùng các chuỗi đã nhúng sẵn.
- Khi chạy source, chương trình ưu tiên đọc file `.mcr` trong `Macro`, nên có thể chỉnh file và thử ngay trước khi build lại.

## Lưu ý kỹ thuật

- Các địa chỉ bộ nhớ và hàm nội bộ đang khớp với bản `Engine.exe` hiện tại. Client khác build có thể cần cập nhật địa chỉ.
- Parser `.mcr` hỗ trợ `KeyDown`, `KeyUp`, `KeyPress`, `RightButtonDown` và `RightButtonUp`.
- Hãy giữ nguyên cấu trúc thư mục khi chạy source hoặc build bằng VS Code.
