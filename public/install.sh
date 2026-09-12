#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${PURPLE}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║                                                           ║"
echo "  ║                  APPLE FACE ID FOR MAC                    ║"
echo "  ║             Your Face. Your Access. Down The Notch.       ║"
echo "  ║                                                           ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${YELLOW}[!] Error: Face ID for Mac is only supported on macOS.${NC}"
    exit 1
fi

ARCH=$(uname -m)
echo -e "${BLUE}[*] Detected Architecture: ${BOLD}${ARCH} (macOS $(sw_vers -productVersion))${NC}"

# Target install directory
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"
APP_TARGET="$INSTALL_DIR/FaceIDMac.app"

# Determine Download URL
SERVER_HOST="${FACEID_HOST:-}"
if [[ -z "$SERVER_HOST" ]]; then
    SERVER_HOST="https://faceid-mac.vercel.app"
fi

ZIP_URL="${SERVER_HOST}/downloads/FaceIDMac.zip"
TEMP_ZIP="/tmp/FaceIDMac.zip"

echo -e "${BLUE}[*] Downloading Face ID for Mac package...${NC}"

# Check if local fallback package exists (if running script locally in repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [[ -f "$SCRIPT_DIR/downloads/FaceIDMac.zip" ]]; then
    echo -e "${GREEN}[✓] Using local distribution bundle...${NC}"
    cp "$SCRIPT_DIR/downloads/FaceIDMac.zip" "$TEMP_ZIP"
elif [[ -f "$SCRIPT_DIR/../public/downloads/FaceIDMac.zip" ]]; then
    echo -e "${GREEN}[✓] Using repository bundle...${NC}"
    cp "$SCRIPT_DIR/../public/downloads/FaceIDMac.zip" "$TEMP_ZIP"
else
    # Download over HTTP
    if ! curl -fsSL "$ZIP_URL" -o "$TEMP_ZIP" 2>/dev/null; then
        echo -e "${YELLOW}[!] Downloading from primary portal...${NC}"
        # Fallback to direct host if provided
        curl -fSL "https://raw.githubusercontent.com/Souvik7661/MacSight/main/public/downloads/FaceIDMac.zip" -o "$TEMP_ZIP" 2>/dev/null || true
    fi
fi

# If zip still doesn't exist, check local workspace build
if [[ ! -f "$TEMP_ZIP" ]] && [[ -d "/Users/souvikkundu/Desktop/FaceId/FaceIDMac.app" ]]; then
    echo -e "${CYAN}[*] Bundling from local workspace release...${NC}"
    (cd /Users/souvikkundu/Desktop/FaceId && zip -r -q -y "$TEMP_ZIP" FaceIDMac.app)
fi

if [[ ! -f "$TEMP_ZIP" ]]; then
    echo -e "${YELLOW}[!] Could not download installer package. Please visit the web link to download directly.${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] Download complete.${NC}"

# Extract
echo -e "${BLUE}[*] Installing Face ID to ${APP_TARGET}...${NC}"
rm -rf "$APP_TARGET"
unzip -q -o "$TEMP_ZIP" -d "$INSTALL_DIR"
rm -f "$TEMP_ZIP"

# Remove macOS quarantine bit
xattr -cr "$APP_TARGET" 2>/dev/null || true

echo -e "${GREEN}[✓] Installed successfully.${NC}"
echo ""
echo -e "${CYAN}${BOLD}[*] Launching Face ID Notch Service...${NC}"
open "$APP_TARGET"

echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✨ FACE ID FOR MAC IS NOW ACTIVE! ✨${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Follow the on-screen prompts:${NC}"
echo -e "  1. ${YELLOW}Grant PC Access${NC} (Accessibility) when prompted to interact with lock screen."
echo -e "  2. ${YELLOW}Grant Camera Access${NC} to enable real-time contour scanning."
echo -e "  3. Look directly into your camera notch — Face ID will enroll and arm your lock screen!"
echo ""
echo -e "${PURPLE}Keyboard Shortcut:${NC} Press ${BOLD}⌘L${NC} anytime to lock or test Face ID down the notch."
echo -e "${PURPLE}Menu Bar:${NC} Click the Face ID icon in your macOS menu bar for settings & options."
echo ""
