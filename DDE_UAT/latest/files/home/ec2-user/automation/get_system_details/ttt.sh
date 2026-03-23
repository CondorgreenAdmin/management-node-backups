#!/bin/bash
# Filename: collect-system-info.sh
# Usage: ./collect-system-info.sh
# Output: ./system-report-<hostname>/

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
HOSTNAME=$(hostname)
REPORT_DIR="./system-report-${HOSTNAME}-${TIMESTAMP}"

mkdir -p "$REPORT_DIR"

echo "Collecting system info for $HOSTNAME into $REPORT_DIR ..."

# 1. OS & Kernel Info
echo "== OS Info ==" > "$REPORT_DIR/os.txt"
cat /etc/os-release >> "$REPORT_DIR/os.txt"
uname -a >> "$REPORT_DIR/os.txt"

# 2. Installed Packages
echo "== Installed Packages ==" > "$REPORT_DIR/packages.txt"
if command -v rpm >/dev/null 2>&1; then
    rpm -qa | sort >> "$REPORT_DIR/packages.txt"
elif command -v dpkg >/dev/null 2>&1; then
    dpkg -l | sort >> "$REPORT_DIR/packages.txt"
fi

# 3. Running Services
echo "== Running Services ==" > "$REPORT_DIR/running-services.txt"
systemctl list-units --type=service --state=running >> "$REPORT_DIR/running-services.txt"

# 4. Enabled Services
echo "== Enabled Services ==" > "$REPORT_DIR/enabled-services.txt"
systemctl list-unit-files | grep enabled >> "$REPORT_DIR/enabled-services.txt"

# 5. Users & Groups
echo "== Users ==" > "$REPORT_DIR/users.txt"
cut -d: -f1 /etc/passwd | sort >> "$REPORT_DIR/users.txt"

echo "== Groups ==" > "$REPORT_DIR/groups.txt"
cut -d: -f1 /etc/group | sort >> "$REPORT_DIR/groups.txt"

# 6. Important Config Files (basic /etc snapshot)
echo "== /etc File List ==" > "$REPORT_DIR/etc-files.txt"
find /etc -type f | sort >> "$REPORT_DIR/etc-files.txt"

# Optional: MD5 checksum of /etc files to catch modifications
echo "== /etc File Checksums ==" > "$REPORT_DIR/etc-md5.txt"
find /etc -type f -exec md5sum {} \; | sort >> "$REPORT_DIR/etc-md5.txt"

# 7. Installed Binaries in /usr/bin & /usr/local/bin
echo "== /usr/bin Binaries ==" > "$REPORT_DIR/usr-bin.txt"
ls -l /usr/bin | sort >> "$REPORT_DIR/usr-bin.txt"

echo "== /usr/local/bin Binaries ==" > "$REPORT_DIR/usr-local-bin.txt"
ls -l /usr/local/bin | sort >> "$REPORT_DIR/usr-local-bin.txt"

echo "System info collection completed."
echo "Report saved in $REPORT_DIR"
