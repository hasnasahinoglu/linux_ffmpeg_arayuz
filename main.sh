#!/bin/bash

# Modülleri içeri aktar
source ./core.sh
source ./gui_module.sh
source ./tui_module.sh

# Ana Menü (Karşılama Ekranı)
while true; do
    choice=$(whiptail --title "PARDUS ffmpeg Arayüzü" --menu \
        "Hoş geldiniz! Lütfen kullanmak istediğiniz arayüzü seçin:" 15 60 3 \
        "1" "Grafik Arayüzü (GUI - YAD)" \
        "2" "Terminal Arayüzü (TUI - Whiptail)" \
        "3" "Çıkış" 3>&1 1>&2 2>&3)

    case $? in
        0) # Seçim yapıldı
            case $choice in
                1) run_gui ;;
                2) run_tui ;;
                3) exit 0 ;;
            esac
            ;;
        *) # İptal veya ESC
            exit 0
            ;;
    esac
done
