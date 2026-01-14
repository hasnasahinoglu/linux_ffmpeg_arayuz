#!/bin/bash

# =========================================================
# TUI İÇİN MODÜL FONKSİYONLARI
# =========================================================

open_tui_converter() {
    # 1. Durum Değişkenleri (State)
    local input_file=""
    local format="mp4"
    local target_file=""
    local quality_sel="Dengeli (Standart)"
    local res_sel="Orijinal"
    local no_audio="FALSE"

    # Döngü Değişkenleri
    local choice
    local display_input
    local display_target
    local display_audio

    while true; do
        
        # --- A. OTOMATİK HAZIRLIKLAR ---
        
        # Dosya ismi gösterimi
        if [ -n "$input_file" ]; then
            display_input="$(basename "$input_file")"
            
            # Otomatik İsimlendirme Mantığı
            local current_ext="${target_file##*.}"
            if [ -z "$target_file" ] || [ "$current_ext" != "$format" ]; then
                target_file="${input_file%.*}.${format}"
            fi
            display_target="$(basename "$target_file")"
        else
            display_input="[ SEÇİLMEDİ ]"
            display_target="[ OTOMATİK ]"
        fi

        # Ses Durumu Gösterimi
        if [ "$no_audio" == "TRUE" ]; then
            display_audio="EVET (Sesi Sil)"
        else
            display_audio="HAYIR (Sesi Koru)"
        fi

        # --- B. DASHBOARD MENÜSÜ ---
        # DÜZELTME: Ayırıcı çizgi (------------------) kaldırıldı, hatalı seçim engellendi.
        
        choice=$(whiptail --title "Pardus Video Dönüştürücü (TUI)" --menu \
            "Yön tuşlarıyla ayarları değiştirin, hazır olunca BAŞLAT diyin." 20 75 8 \
            "1" "Kaynak Dosya:  $display_input" \
            "2" "Format:        [$format]" \
            "3" "Kalite:        [$quality_sel]" \
            "4" "Çözünürlük:    [$res_sel]" \
            "5" "Sesi Kaldır:   [$display_audio]" \
            "6" "Çıktı Yolu:    $display_target" \
            "7" ">>> DÖNÜŞTÜRMEYİ BAŞLAT <<<" \
            "8" "Ana Menüye Dön" 3>&1 1>&2 2>&3)

        local exit_status=$?
        
        # İptal veya ESC basılırsa fonksiyondan çık (run_tui'ye döner)
        if [ $exit_status -ne 0 ]; then return; fi

        # --- C. AKSİYONLAR ---
        
        case "$choice" in
            "1") # KAYNAK DOSYA SEÇİMİ
                local temp_input=$(whiptail --title "Kaynak Dosya" --inputbox \
                    "Video dosyasının tam yolunu girin:" 10 60 "$input_file" 3>&1 1>&2 2>&3)
                
                if [ $? -eq 0 ] && [ -n "$temp_input" ]; then
                    if [ -f "$temp_input" ]; then
                        input_file="$temp_input"
                        target_file=""
                    else
                        whiptail --msgbox "Hata: Dosya bulunamadı!" 8 40
                    fi
                fi
                ;;

            "2") # FORMAT SEÇİMİ
                local temp_format=$(whiptail --title "Format Seç" --menu "Hedef formatı seçin:" 15 60 5 \
                    "mp4" "Standart (En Uyumlu)" \
                    "mkv" "Matroska (Gelişmiş)" \
                    "webm" "Web İçin (VP9)" \
                    "avi" "Eski Cihazlar" \
                    "mov" "Apple QuickTime" \
                    "flv" "Flash Video" 3>&1 1>&2 2>&3)
                
                [ $? -eq 0 ] && format="$temp_format"
                ;;

            "3") # KALİTE SEÇİMİ
                local temp_quality=$(whiptail --title "Kalite Ayarı" --menu "Kalite/Boyut dengesini seçin:" 15 60 5 \
                    "Görsel Kayıpsız (Büyük Dosya)" "Orijinale en yakın" \
                    "Yüksek Kalite" "İyi görüntü" \
                    "Dengeli (Standart)" "Varsayılan önerilen" \
                    "Küçük Boyut (WhatsApp vb.)" "Hızlı paylaşım" \
                    "Arşivlik (En Küçük)" "Düşük kalite, minik boyut" 3>&1 1>&2 2>&3)
                
                [ $? -eq 0 ] && quality_sel="$temp_quality"
                ;;

            "4") # ÇÖZÜNÜRLÜK SEÇİMİ
                local temp_res=$(whiptail --title "Çözünürlük" --menu "Video boyutunu değiştir:" 15 60 4 \
                    "Orijinal" "Boyutları koru" \
                    "1080p" "Full HD" \
                    "720p" "HD Ready" \
                    "480p" "SD (Eski TV)" 3>&1 1>&2 2>&3)
                
                [ $? -eq 0 ] && res_sel="$temp_res"
                ;;

            "5") # SES AYARI (Toggle)
                if [ "$no_audio" == "FALSE" ]; then
                    no_audio="TRUE"
                else
                    no_audio="FALSE"
                fi
                ;;
            
            "6") # ÇIKTI YOLU DÜZENLEME
                local temp_target=$(whiptail --title "Çıktı Yolu" --inputbox \
                    "Kaydedilecek dosya ismini düzenleyin:" 10 60 "$target_file" 3>&1 1>&2 2>&3)
                
                [ $? -eq 0 ] && [ -n "$temp_target" ] && target_file="$temp_target"
                ;;

            "8") # ANA MENÜYE DÖN
                return # open_tui_converter fonksiyonundan çıkar, run_tui'ye döner
                ;;

            "7") # DÖNÜŞTÜRMEYİ BAŞLAT
                if [ -z "$input_file" ]; then
                    whiptail --msgbox "Lütfen önce Kaynak Dosya (1) seçin!" 8 45
                    continue
                fi

                local filename_no_ext="${target_file%.*}"
                local current_extension="${target_file##*.}"
                if [ "$current_extension" != "$format" ]; then
                    target_file="${filename_no_ext}.${format}"
                fi

                if [ "$input_file" == "$target_file" ]; then
                    whiptail --msgbox "Hata: Kaynak ve Hedef aynı olamaz!\nLütfen çıktı ismini değiştirin." 10 60
                    continue
                fi

                if [ -f "$target_file" ]; then
                    if ! whiptail --yesno "Dosya zaten var. Üzerine yazılsın mı?" 10 60; then
                        continue
                    fi
                fi

                # İŞLEM
                local duration=$(get_duration "$input_file")
                
                convert_with_progress "$input_file" "$target_file" "$duration" "$quality_sel" "$res_sel" "$no_audio" | \
                whiptail --gauge "Dönüştürülüyor: $(basename "$target_file")" 10 60 0

                if [ ${PIPESTATUS[0]} -eq 0 ]; then
                    whiptail --msgbox "İşlem Başarıyla Tamamlandı!" 10 60
                    # DÜZELTME: return yerine continue.
                    # Böylece işlem bitince ayarlara geri döner, kullanıcı isterse başka işlem yapar.
                    # Çıkmak isterse kendisi "Ana Menüye Dön" der.
                    continue 
                else
                    whiptail --msgbox "Hata: Dönüştürme başarısız oldu." 10 60
                fi
                ;;
            
            *) # Herhangi bir hata durumunda döngüye devam et
                continue
                ;;
        esac
    done
}

# --- B. YENİ: Medya Bilgisi Modülü ---
open_tui_media_info() {
    local input_file=""
    local output_text=""

    while true; do
        # Menü Başlığı
        local current_selection="[ SEÇİLMEDİ ]"
        if [ -n "$input_file" ]; then
            current_selection="$(basename "$input_file")"
        fi

        # İşlem Menüsü
        local choice=$(whiptail --title "Medya Bilgisi (TUI)" --menu \
            "Dosya bilgilerini görüntülemek için seçim yapın:" 15 70 3 \
            "1" "Dosya Seç / Yolu Gir ($current_selection)" \
            "2" "Raporu Görüntüle" \
            "3" "Ana Menüye Dön" 3>&1 1>&2 2>&3)
        
        if [ $? -ne 0 ]; then return; fi # İptal/ESC

        case "$choice" in
            "1") # DOSYA SEÇİMİ
                local temp_input=$(whiptail --title "Dosya Yolu" --inputbox \
                    "Analiz edilecek dosyanın TAM YOLUNU girin:\n(Örn: /home/kullanici/video.mp4)" 10 60 "$input_file" 3>&1 1>&2 2>&3)
                
                if [ $? -eq 0 ] && [ -n "$temp_input" ]; then
                    if [ -f "$temp_input" ]; then
                        input_file="$temp_input"
                    else
                        whiptail --msgbox "Hata: Dosya bulunamadı!\nLütfen yolu kontrol edin." 8 50
                    fi
                fi
                ;;
            
            "2") # RAPORU GÖSTER
                if [ -z "$input_file" ]; then
                    whiptail --msgbox "Lütfen önce 'Dosya Seç' (1) menüsünü kullanın." 8 50
                    continue
                fi

                # core.sh'tan bilgiyi çek
                # Lütfen Bekleyin ekranı (büyük dosyalar için)
                {
                    sleep 0.5
                    echo 100
                } | whiptail --gauge "Dosya analizi yapılıyor..." 6 50 0

                output_text=$(get_video_metadata "$input_file")

                # Sonucu Scroll Edilebilir Kutuda Göster
                whiptail --title "Dosya Analiz Raporu" --scrolltext --msgbox "$output_text" 20 75
                ;;
            
            "3") # ÇIKIŞ
                return
                ;;
        esac
    done
}

# --- C. SES DÖNÜŞTÜRME MODÜLÜ (TUI GÜNCEL) ---
open_tui_audio_converter() {
    local input_file=""
    local format="mp3"
    local target_file=""
    local bitrate="192k"

    while true; do
        # Ekran Değişkenleri
        local display_input="[ SEÇİLMEDİ ]"
        [ -n "$input_file" ] && display_input="$(basename "$input_file")"
        
        local display_target="[ OTOMATİK ]"
        
        # Otomatik İsimlendirme (Görüntüleme için)
        if [ -n "$input_file" ]; then
            local current_ext="${target_file##*.}"
            if [ -z "$target_file" ] || [ "$current_ext" != "$format" ]; then
                target_file="${input_file%.*}.${format}"
            fi
            display_target="$(basename "$target_file")"
        fi

        # TUI DASHBOARD MENÜSÜ
        local choice=$(whiptail --title "Ses Stüdyosu (TUI)" --menu \
            "Ses ayıklama ve dönüştürme ayarları:" 20 75 7 \
            "1" "Kaynak Dosya:  $display_input" \
            "2" "Format:        [$format]" \
            "3" "Bitrate:       [$bitrate]" \
            "4" "Çıktı Yolu:    $display_target" \
            "5" ">>> DÖNÜŞTÜRMEYİ BAŞLAT <<<" \
            "6" "Ana Menüye Dön" 3>&1 1>&2 2>&3)

        local exit_status=$?
        
        # KRİTİK DÜZELTME: İptal/ESC durumunda fonksiyondan çık
        if [ $exit_status -ne 0 ]; then return; fi

        case "$choice" in
            "1") # DOSYA SEÇ
                local temp_input=$(whiptail --inputbox "Dosya yolunu girin:" 10 60 "$input_file" 3>&1 1>&2 2>&3)
                if [ $? -eq 0 ] && [ -n "$temp_input" ]; then
                    if [ -f "$temp_input" ]; then
                        input_file="$temp_input"
                        target_file="" 
                    else
                        whiptail --msgbox "Hata: Dosya bulunamadı!" 8 40
                    fi
                fi
                ;;
            "2") # FORMAT SEÇ
                local temp_fmt=$(whiptail --menu "Ses formatını seçin:" 15 60 4 \
                    "mp3" "Standart (En yaygın)" \
                    "m4a" "AAC (Yüksek verim)" \
                    "flac" "Kayıpsız (Büyük dosya)" \
                    "wav" "Ham Ses (WAV)" 3>&1 1>&2 2>&3)
                [ $? -eq 0 ] && format="$temp_fmt"
                ;;
            "3") # BITRATE SEÇ
                local temp_br=$(whiptail --menu "Ses kalitesini seçin:" 15 60 3 \
                    "320k" "Yüksek Kalite" \
                    "192k" "Standart" \
                    "128k" "Düşük / Konuşma" 3>&1 1>&2 2>&3)
                [ $? -eq 0 ] && bitrate="$temp_br"
                ;;
            "4") # ÇIKTI DÜZENLE
                local temp_tgt=$(whiptail --inputbox "Çıktı ismini düzenle:" 10 60 "$target_file" 3>&1 1>&2 2>&3)
                [ $? -eq 0 ] && [ -n "$temp_tgt" ] && target_file="$temp_tgt"
                ;;
            "6") return ;; # Geri Dön
            "5") # BAŞLAT
                if [ -z "$input_file" ]; then
                    whiptail --msgbox "Lütfen dosya seçin!" 8 40; continue
                fi
                
                # --- AKILLI UZANTI DÜZELTME (TUI İÇİN) ---
                local filename_no_ext="${target_file%.*}"
                local current_extension="${target_file##*.}"
                if [ "$current_extension" != "$format" ]; then
                    target_file="${filename_no_ext}.${format}"
                fi

                # Çakışma Kontrolleri
                if [ "$input_file" == "$target_file" ]; then
                    whiptail --msgbox "Kaynak ve Hedef aynı olamaz!\nLütfen çıktı ismini değiştirin." 8 60; continue
                fi
                if [ -f "$target_file" ]; then
                    if ! whiptail --yesno "Dosya zaten var. Üzerine yazılsın mı?" 8 40; then continue; fi
                fi

                # İşlem
                local duration=$(get_duration "$input_file")
                convert_audio_with_progress "$input_file" "$target_file" "$duration" "$format" "$bitrate" | \
                whiptail --gauge "Ses işleniyor: $(basename "$target_file")" 10 60 0

                if [ ${PIPESTATUS[0]} -eq 0 ]; then
                    whiptail --msgbox "İşlem Tamamlandı!" 8 40
                    continue # İşlem bitince menüde kal
                else
                    whiptail --msgbox "Hata oluştu!" 8 40
                fi
                ;;
        esac
    done
}

# =========================================================
# ANA YÖNLENDİRİCİ (TUI LOOP FIX)
# =========================================================
run_tui() {
    while true; do
        local choice=$(whiptail --title "Pardus ffmpeg TUI" --menu \
            "Hoş Geldiniz! İşlem seçiniz:" 15 60 4 \
            "1" "Video Dönüştürme Stüdyosu" \
            "2" "Ses Dönüştürme / Ayıklama" \
            "3" "Dosya Bilgisi (Media Info)" \
            "4" "Çıkış" 3>&1 1>&2 2>&3)
        
        local exit_status=$?
        
        # DÜZELTME: İptal (1) veya ESC (255) durumunda döngüyü kır
        if [ $exit_status -ne 0 ] || [ "$choice" == "4" ]; then
            break 
        fi

        case "$choice" in
            "1") open_tui_converter ;;
            "2") open_tui_audio_converter ;;
            "3") open_tui_media_info ;;
        esac
    done
}