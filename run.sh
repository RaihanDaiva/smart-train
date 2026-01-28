#!/bin/bash

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Smart Train - Auto Run Script     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Cek apakah Dart tersedia
if ! command -v dart &> /dev/null; then
    echo -e "${RED}DART TIDAK DITEMUKAN!${NC}"
    echo -e "${YELLOW}> Install Flutter terlebih dahulu${NC}"
    exit 1
fi

# Cek apakah Flutter tersedia
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}FLUTTER TIDAK DITEMUKAN!${NC}"
    echo -e "${YELLOW}> Install Flutter terlebih dahulu${NC}"
    exit 1
fi

# Step 1: Generate .env
echo -e "${BLUE}o Step 1: Auto-detecting IP Address...${NC}"
dart run scripts/generate_env.dart

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}GAGAL GENERATE .env${NC}"
    echo -e "${YELLOW}> Pastikan laptop terhubung ke WiFi/Ethernet${NC}"
    exit 1
fi

echo ""

# Step 2: Tampilkan pilihan
echo -e "${BLUE}o Step 2: Pilih mode run:${NC}"
echo -e "  ${GREEN}1)${NC} Flutter Run (Debug Mode, Usually Recommended)"
echo -e "  ${GREEN}2)${NC} Flutter Run Release"
echo -e "  ${GREEN}3)${NC} Flutter Build APK"
echo -e "  ${GREEN}4)${NC} Exit"
echo ""
read -p "Pilih (1-4): " choice

case $choice in
    1)
        echo ""
        echo -e "${GREEN}Menjalankan Flutter Run (Debug)...${NC}"
        flutter run
        ;;
    2)
        echo ""
        echo -e "${GREEN}Menjalankan Flutter Run (Release)...${NC}"
        flutter run --release
        ;;
    3)
        echo ""
        echo -e "${GREEN}Building APK...${NC}"
        flutter build apk --release
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}APK BERHASIL DIBUAT!${NC}"
            echo -e "${BLUE}> Lokasi: build/app/outputs/flutter-apk/app-release.apk${NC}"
        fi
        ;;
    4)
        echo -e "${YELLOW}Bye!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}PILIHAN TIDAK VALID!!${NC}"
        exit 1
        ;;
esac