# DoiZ-Cursor

Bộ con trỏ chuột theo style DoiZ, dựng từ hình dạng Bibata Modern (GPL-3.0, xem `LICENSE`). Nguồn SVG nằm ở `svg/original` và `svg/modern`.

- Thân con trỏ: `background`, viền: `foreground` trong `theme/theme.conf`.
- Huy hiệu dùng `accent_alt`, `blue`, `green`, `red`, `yellow`.
- Bốn con trỏ resize góc và bốn nan của vòng chờ (`wait`, `left_ptr_watch`) mỗi cái một màu: khi đổi wallpaper, `build.py --apply` phân tích 8 màu của ảnh (`colorthief`), làm sáng/bão hoà như `boost_color`, chọn 4 màu khác sắc độ nhất; bản dựng sẵn dùng `cyan`, `red`, `green`, `yellow`.
- Bản dựng sẵn nằm ở `DoiZ-Cursor/`; `install.sh` chép nó vào `~/.local/share/icons/`.

## Đổi màu theo wallpaper

Mỗi lần `apply-theme.py` đổi wallpaper hoặc chế độ sáng/tối, nó chạy nền `build.py --apply`:

1. Đọc palette mới từ `theme.conf` và ảnh trong `~/.local/state/doiz/current-wallpaper`, vẽ lại SVG rồi ghi XCursor (khoảng 2 giây, không cần `clickgen`).
2. Ghi vào `DoiZ-Cursor-A` hoặc `DoiZ-Cursor-B` luân phiên để các ứng dụng đang mở nhận theme mới, đồng thời cập nhật `DoiZ-Cursor` cho phiên đăng nhập sau.
3. Cập nhật `gtk-3.0`/`gtk-4.0` settings, gsettings, `~/.local/share/icons/default` và chạy `hyprctl setcursor`.

Kích thước lấy từ `XCURSOR_SIZE` (mặc định 24).

## Dựng tay

```sh
pacman -S python-cairosvg python-pillow
~/.config/cursor/build.py --install
~/.config/cursor/build.py --install --fill 1A1D33 --outline D6DAED --accent 6A85CC
~/.config/cursor/build.py --apply
~/.config/cursor/build.py --install --wallpaper /đường/dẫn/ảnh.jpg
~/.config/cursor/build.py --install --shape soft
~/.config/cursor/build.py --install --shape original
```

Có ba kiểu: `modern` (mặc định, bo tròn), `soft` (Original bo nhẹ), `original` (góc cạnh). Độ bo của `soft` chỉnh bằng `DOIZ_CURSOR_ROUND` (mặc định 4.5, càng lớn càng tròn).

Đặt `DOIZ_CURSOR_SHAPE=soft` (hoặc `original`) để đổi kiểu mặc định, kể cả khi tự đổi màu theo wallpaper.
