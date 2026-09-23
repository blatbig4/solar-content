#!/usr/bin/env bash
# ============================================================================
# vps-setup.sh — Cài đặt phục vụ /huongdan + /sanpham từ repo solar-content.
# Chạy MỘT LẦN trên VPS (root). An toàn: sao lưu nginx + kiểm tra + tự khôi phục.
# ============================================================================
set -euo pipefail
REPO="https://github.com/blatbig4/solar-content.git"
DEST="/var/www/solar-content"

echo "==> [1/3] Tải nội dung về $DEST"
mkdir -p /var/www
if [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull --quiet
else
  git clone --quiet "$REPO" "$DEST"
fi
echo "    OK — có: $(ls "$DEST")"

echo "==> [2/3] Cron tự cập nhật mỗi 2 phút"
CRON_LINE="*/2 * * * * cd $DEST && git pull --quiet >/dev/null 2>&1"
( crontab -l 2>/dev/null | grep -v "$DEST" || true ; echo "$CRON_LINE" ) | crontab -
echo "    OK — $(crontab -l | grep "$DEST")"

echo "==> [3/3] Cấu hình nginx (an toàn: sao lưu + kiểm tra + tự khôi phục)"
SNIP="/etc/nginx/snippets/solar-content.conf"
mkdir -p /etc/nginx/snippets
cat > "$SNIP" <<'NGINX'
# /huongdan + /sanpham phục vụ tĩnh từ repo solar-content (KHÔNG qua node app)
location = /huongdan { return 301 /huongdan/; }
location /huongdan/ {
    alias /var/www/solar-content/huongdan/;
    index index.html;
    try_files $uri $uri/ /huongdan/index.html;
}
location = /sanpham { return 301 /sanpham/; }
location /sanpham/ {
    alias /var/www/solar-content/sanpham/;
    index index.html;
    try_files $uri $uri/ /sanpham/index.html;
}
NGINX
echo "    Đã tạo snippet: $SNIP"

CONF=$(grep -rl "solarcloud.io.vn" /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null | head -1 || true)
if [ -z "${CONF:-}" ]; then
  echo "    !! KHÔNG tìm thấy file nginx chứa 'solarcloud.io.vn'."
  echo "       Hãy thêm dòng  include snippets/solar-content.conf;  vào TRONG khối server {} rồi: nginx -t && systemctl reload nginx"
  exit 0
fi
echo "    File nginx: $CONF"

if grep -q "solar-content.conf" "$CONF"; then
  echo "    include đã có sẵn — bỏ qua chèn."
else
  BAK="$CONF.bak-$(date +%s)"
  cp "$CONF" "$BAK"
  # Chèn 'include ...' vào TRƯỚC 'location /' đầu tiên trong file server block.
  sed -i '0,/location \/[[:space:]]*{/s//include snippets\/solar-content.conf;\n    location \/ {/' "$CONF"
  if ! grep -q "solar-content.conf" "$CONF"; then
    echo "    !! Không tự chèn được (không thấy 'location /'). Khôi phục & thêm tay."
    cp "$BAK" "$CONF"
    echo "       Thêm dòng  include snippets/solar-content.conf;  vào khối server {} rồi reload nginx."
    exit 0
  fi
  echo "    Đã chèn include (sao lưu: $BAK)"
fi

if nginx -t 2>/tmp/nginxtest; then
  systemctl reload nginx
  echo "==> HOÀN TẤT. Kiểm tra: https://solarcloud.io.vn/huongdan  và  /sanpham"
else
  echo "    !! nginx -t LỖI — KHÔI PHỤC cấu hình cũ để site không sập:"
  cat /tmp/nginxtest
  LAST_BAK=$(ls -t "$CONF".bak-* 2>/dev/null | head -1 || true)
  [ -n "$LAST_BAK" ] && cp "$LAST_BAK" "$CONF" && nginx -t && systemctl reload nginx && echo "    Đã khôi phục. Site vẫn chạy bản cũ. Báo lại để sửa tay."
fi
