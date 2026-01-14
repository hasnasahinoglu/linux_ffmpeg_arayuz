#!/bin/bash

# Renk tanımlamaları (Daha iyi bir görünüm için)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # Renk Yok

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}   PARDUS ffmpeg Arayüzü Kurulum Sihirbazı    ${NC}"
echo -e "${BLUE}==============================================${NC}"

# 1. Adım: İzinlerin Düzenlenmesi
echo -e "\n${YELLOW}[1/3] Dosya izinleri yapılandırılıyor...${NC}"
# Kendi ismini hariç tutarak veya dahil ederek tüm sh dosyalarına izin ver
chmod +x *.sh
echo -e "${GREEN}✔ Tüm script dosyaları için çalıştırma izni verildi.${NC}"

# 2. Adım: Bağımlılık Kontrolü
echo -e "\n${YELLOW}[2/3] Bağımlılıklar kontrol ediliyor...${NC}"
deps=("ffmpeg" "yad" "whiptail" "bc")
missing_deps=()

for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        missing_deps+=("$dep")
    else
        echo -e "${GREEN}✔ $dep zaten kurulu.${NC}"
    fi
done

# 3. Adım: Eksik Paketlerin Yüklenmesi
if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "\n${YELLOW}Sistemde eksik paketler bulundu: ${missing_deps[*]}${NC}"
    echo -e "${BLUE}Paket listesi güncelleniyor, lütfen bekleyin...${NC}"
    
    # apt update çıktısını temiz tutmak için sadece hataları gösteriyoruz
    sudo apt update -qq
    
    echo -e "${BLUE}Eksik paketler yükleniyor...${NC}"
    # Paket yükleme sırasında sadece ilerlemeyi görmek için -y kullanıyoruz
    sudo apt install -y "${missing_deps[@]}" > /dev/null
    
    echo -e "${GREEN}✔ Tüm bağımlılıklar başarıyla yüklendi.${NC}"
else
    echo -e "${GREEN}✔ Bağımlılık kontrolü tamamlandı, her şey hazır.${NC}"
fi

# 4. Adım: Bitiriş
echo -e "\n${BLUE}==============================================${NC}"
echo -e "${GREEN}Kurulum Başarıyla Tamamlandı!${NC}"
echo -e "Uygulamayı başlatmak için: ${YELLOW}./main.sh${NC}"
echo -e "${BLUE}==============================================${NC}"