#!/usr/bin/env bash
#
# apply-not-assist-branding.sh
# ---------------------------------------------------------------------------
# Trasforma una copia dei sorgenti di RustDesk nel brand "NOT-ASSIST".
#
# COSA FA:
#   1. Cambia il nome applicazione (APP_NAME) da "RustDesk" a "NOT-ASSIST"
#   2. Cambia l'organizzazione/namespace dei dati (ORG) in "com.notai"
#   3. Rinomina il prodotto nelle schermate e nei metadati (macOS e Windows)
#   4. Rinomina il bundle macOS in NOT-ASSIST.app (incluso il workflow di build)
#   5. Sostituisce tutte le icone con il logo NOT-ASSIST
#
# COSA NON TOCCA (di proposito, per non rompere la compilazione):
#   - Il nome del file eseguibile interno resta "rustdesk.exe" / binario "rustdesk".
#     E' solo il nome tecnico del file: l'utente vede ovunque "NOT-ASSIST".
#
# USO:
#   - Copiare questa cartella "branding/" nella RADICE del repository RustDesk
#     (dove si trovano Cargo.toml e build.py).
#   - Eseguire:   bash branding/apply-not-assist-branding.sh
#
# Lo script e' DIFENSIVO e IDEMPOTENTE: se una modifica risulta gia' applicata
# la salta; se una stringa attesa non esiste, avvisa e prosegue.
# ---------------------------------------------------------------------------

set -u
APP="NOT-ASSIST"
ORG="com.notai"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICONS="$SCRIPT_DIR/icons"
ROOT="$(pwd)"

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }
info() { printf "\n\033[1m%s\033[0m\n" "$1"; }

if [[ ! -f "$ROOT/Cargo.toml" || ! -f "$ROOT/build.py" ]]; then
  echo "ERRORE: eseguire dalla radice del repository RustDesk (manca Cargo.toml/build.py)."; exit 1
fi
[[ -d "$ICONS" ]] || { echo "ERRORE: cartella icone non trovata: $ICONS"; exit 1; }

# repl FILE  PATTERN  REPLACEMENT  DESC
#   PATTERN/REPLACEMENT sono espressioni perl; usare \Q..\E non necessario qui.
repl() {
  local f="$1" pat="$2" rep="$3" d="$4"
  if [[ ! -f "$f" ]]; then warn "File assente ($d): $f"; return; fi
  PAT="$pat" REP="$rep" perl -0777 -i -pe 'my $p=$ENV{PAT}; my $r=$ENV{REP}; s/$p/$r/g;' "$f"
  if grep -qF -- "$rep" "$f" 2>/dev/null; then ok "$d"; else warn "Non applicato ($d) in $f — sorgente forse cambiato."; fi
}

info "1) Nome applicazione e organizzazione (submodule hbb_common)"
CFG="libs/hbb_common/src/config.rs"
if [[ ! -f "$CFG" ]]; then
  warn "Submodule hbb_common non inizializzato: eseguo git submodule update --init --recursive"
  git submodule update --init --recursive >/dev/null 2>&1 || warn "init submodule fallito"
fi
repl "$CFG" 'RwLock::new\("RustDesk"\.to_owned\(\)\)' 'RwLock::new("'"$APP"'".to_owned())' "APP_NAME -> $APP"
repl "$CFG" 'RwLock::new\("com\.carriez"\.to_owned\(\)\)' 'RwLock::new("'"$ORG"'".to_owned())' "ORG -> $ORG"

info "2) Descrizione pacchetto (Cargo.toml)"
repl "Cargo.toml" 'RustDesk Remote Desktop' "$APP Remote Desktop" "description"

info "3) Windows — titolo finestra e metadati del file"
repl "flutter/windows/runner/main.cpp" 'L"RustDesk"' 'L"'"$APP"'"' "titolo finestra"
RC="flutter/windows/runner/Runner.rc"
repl "$RC" 'RustDesk Remote Desktop' "$APP Remote Desktop" "FileDescription"
repl "$RC" 'VALUE "ProductName", "RustDesk"' 'VALUE "ProductName", "'"$APP"'"' "ProductName"
repl "$RC" 'Purslane Tech Pte\. Ltd\.' 'NOT-AI' "CompanyName"

info "4) macOS — nome prodotto, bundle id e schema URL"
XC="flutter/macos/Runner/Configs/AppInfo.xcconfig"
repl "$XC" 'PRODUCT_NAME = RustDesk' "PRODUCT_NAME = $APP" "PRODUCT_NAME"
repl "$XC" 'PRODUCT_BUNDLE_IDENTIFIER = com\.carriez\.flutterHbb' "PRODUCT_BUNDLE_IDENTIFIER = $ORG.notassist" "bundle id"
repl "$XC" 'Purslane Tech Pte\. Ltd\.' 'NOT-AI' "copyright"
PL="flutter/macos/Runner/Info.plist"
repl "$PL" '<string>com\.carriez\.rustdesk</string>' "<string>$ORG.notassist</string>" "CFBundleURLName"
repl "$PL" '<string>rustdesk</string>' '<string>not-assist</string>' "schema URL"

info "5) Rinomina bundle macOS RustDesk.app -> $APP.app (workflow + build.py)"
for f in ".github/workflows/flutter-build.yml" "build.py" "res/osx-dist.sh"; do
  repl "$f" 'RustDesk\.app' "$APP.app" "RustDesk.app -> $APP.app in $(basename "$f")"
done

info "6) Icone"
copyi() { if [[ -f "$ICONS/$1" ]]; then mkdir -p "$(dirname "$2")"; cp -f "$ICONS/$1" "$2" && ok "$2"; else warn "icona assente: $1"; fi; }
copyi icon.ico              "flutter/windows/runner/resources/app_icon.ico"
copyi NOT-ASSIST.icns       "flutter/macos/Runner/AppIcon.icns"
copyi icon.png              "res/icon.png"
copyi icon.ico              "res/icon.ico"
copyi mac-icon.png          "res/mac-icon.png"
copyi 128x128.png           "res/128x128.png"
copyi 128x128@2x.png        "res/128x128@2x.png"
copyi 32x32.png             "res/32x32.png"
copyi 64x64.png             "res/64x64.png"
copyi tray-icon.ico         "res/tray-icon.ico"
copyi mac-tray-dark-x2.png  "res/mac-tray-dark-x2.png"
copyi mac-tray-light-x2.png "res/mac-tray-light-x2.png"
copyi icon.svg              "flutter/assets/icon.svg"
copyi logo.svg              "res/logo.svg"
copyi scalable.svg          "res/scalable.svg"

info "FATTO."
echo "Verifica rapida:"
echo "  grep -R \"$APP\" libs/hbb_common/src/config.rs flutter/windows/runner/Runner.rc flutter/macos/Runner/Configs/AppInfo.xcconfig"
echo "Poi: commit + push sul tuo fork e avvio build (vedi GUIDA-NOT-ASSIST.md)."
