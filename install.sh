#!/usr/bin/env bash
set -euo pipefail

PANEL_DIR="${1:-/var/www/pterodactyl}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$SCRIPT_DIR/theme"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/daxxzya-elysium-backup-$STAMP"

echo "=============================================="
echo "   DAXXZYA ELYSIUM THEME INSTALLER"
echo "=============================================="
echo "Panel : $PANEL_DIR"
echo "Backup: $BACKUP"
echo

if [[ ! -d "$PANEL_DIR" ]]; then
  echo "[ERROR] Folder panel tidak ditemukan: $PANEL_DIR"
  echo "Contoh: sudo bash install.sh /var/www/pterodactyl"
  exit 1
fi

mkdir -p "$BACKUP"

# Backup existing frontend files that may be touched.
if [[ -d "$PANEL_DIR/public/assets" ]]; then
  cp -a "$PANEL_DIR/public/assets" "$BACKUP/assets"
fi

# Save a copy of the theme package.
cp -a "$THEME_DIR" "$BACKUP/theme"

# Locate a suitable public stylesheet directory.
ASSET_DIR="$PANEL_DIR/public/assets"
mkdir -p "$ASSET_DIR"

cp "$THEME_DIR/daxxzya-elysium.css" "$ASSET_DIR/daxxzya-elysium.css"
cp "$THEME_DIR/daxxzya-elysium.js" "$ASSET_DIR/daxxzya-elysium.js"

# Try to inject the override into the main HTML entry.
INJECTED=0
for FILE in "$PANEL_DIR/public/index.html" "$PANEL_DIR/public/index.php"; do
  if [[ -f "$FILE" ]]; then
    cp "$FILE" "$BACKUP/$(basename "$FILE").bak"
    if [[ "$FILE" == *.html ]]; then
      if ! grep -q "daxxzya-elysium.css" "$FILE"; then
        sed -i 's#</head>#<link rel="stylesheet" href="/assets/daxxzya-elysium.css"></head>#' "$FILE"
      fi
      if ! grep -q "daxxzya-elysium.js" "$FILE"; then
        sed -i 's#</body>#<script src="/assets/daxxzya-elysium.js"></script></body>#' "$FILE"
      fi
      INJECTED=1
    fi
  fi
done

# If the build uses Blade, add the assets to a dedicated snippet.
if [[ -d "$PANEL_DIR/resources/views" ]]; then
  SNIPPET="$PANEL_DIR/resources/views/daxxzya-elysium.blade.php"
  cat > "$SNIPPET" <<'BLADE'
<link rel="stylesheet" href="{{ asset('assets/daxxzya-elysium.css') }}">
<script src="{{ asset('assets/daxxzya-elysium.js') }}"></script>
BLADE
  INJECTED=1
fi

# Laravel cache clear when artisan exists.
if [[ -f "$PANEL_DIR/artisan" ]]; then
  cd "$PANEL_DIR"
  php artisan view:clear || true
  php artisan cache:clear || true
  php artisan config:clear || true
fi

echo
echo "[OK] Theme files installed."
echo "[OK] Backup: $BACKUP"

if [[ "$INJECTED" -eq 0 ]]; then
  echo
  echo "[NOTE] Build Elysium kamu tidak mempunyai entry file yang dikenali installer."
  echo "       File CSS/JS sudah tersedia di:"
  echo "       $ASSET_DIR/daxxzya-elysium.css"
  echo "       $ASSET_DIR/daxxzya-elysium.js"
  echo "       Asset perlu di-include ke entry frontend sesuai build Elysium kamu."
fi

echo
echo "Selesai. Bersihkan cache browser lalu reload panel."
