#!/usr/bin/env bash
#
# health_check.sh
# Kiểm tra trạng thái (health check) các dịch vụ quan trọng trên hệ thống.
#
# Cách dùng:
#   chmod +x health_check.sh
#   ./health_check.sh
#
# Mã thoát (exit code):
#   0 = tất cả dịch vụ đều đang chạy
#   1 = có ít nhất một dịch vụ đã chết  (hữu ích khi gọi từ cron / CI / Nagios)
#
set -u

# ---------------------------------------------------------------------------
# 2. Khai báo mảng chứa tên các dịch vụ cần kiểm tra
#    (lưu ý: trên CentOS/RHEL/AlmaLinux, dịch vụ SSH tên là "sshd")
# ---------------------------------------------------------------------------
SERVICES=("nginx" "ssh")

# Màu cho terminal: chỉ bật khi đầu ra thực sự là terminal, để log file sạch.
if [[ -t 1 ]]; then
  RED=$'\033[1;31m'
  GREEN=$'\033[1;32m'
  YELLOW=$'\033[1;33m'
  RESET=$'\033[0m'
else
  RED="" GREEN="" YELLOW="" RESET=""
fi

# systemctl là bắt buộc -> báo lỗi sớm nếu máy không dùng systemd
if ! command -v systemctl >/dev/null 2>&1; then
  echo "${RED}LỖI:${RESET} không tìm thấy 'systemctl' (hệ thống này không dùng systemd)." >&2
  exit 2
fi

echo "=== HEALTH CHECK $(date '+%Y-%m-%d %H:%M:%S') ==="

# ---------------------------------------------------------------------------
# 3. Dùng vòng lặp để kiểm tra trạng thái từng dịch vụ
# ---------------------------------------------------------------------------
exit_code=0
failed=()

for service in "${SERVICES[@]}"; do
  # 'systemctl is-active --quiet' trả về 0 nếu dịch vụ đang chạy, khác 0 nếu không.
  if systemctl is-active --quiet "$service"; then
    echo "${GREEN}[ OK ]${RESET}   $service đang chạy"
  else
    # -----------------------------------------------------------------------
    # 4. Nếu dịch vụ chết -> in cảnh báo đỏ ra màn hình
    # -----------------------------------------------------------------------
    echo "${RED}[WARN]${RESET}   $service KHÔNG chạy (đã chết hoặc chưa được cài đặt)!"
    echo "         ${YELLOW}>>> CẢNH BÁO: dịch vụ '$service' cần được kiểm tra ngay! <<<${RESET}"

    # Gợi ý trạng thái thật (failed / inactive / unknown ...) cho người vận hành
    state=$(systemctl is-active "$service" 2>/dev/null || true)
    echo "         Trạng thái: ${state:-không xác định}"

    failed+=("$service")
    exit_code=1
  fi
done

# ---------------------------------------------------------------------------
# Tổng kết
# ---------------------------------------------------------------------------
echo "---------------------------------------"
if (( exit_code == 0 )); then
  echo "${GREEN}Tất cả ${#SERVICES[@]} dịch vụ đều hoạt động bình thường.${RESET}"
else
  echo "${RED}Cảnh báo: ${#failed[@]}/${#SERVICES[@]} dịch vụ gặp sự cố: ${failed[*]}${RESET}"
fi

exit "$exit_code"
