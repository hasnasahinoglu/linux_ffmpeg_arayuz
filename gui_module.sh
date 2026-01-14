#!/bin/bash

# =========================================================
# 1. GLOBAL AYARLAR
# =========================================================
WIN_WIDTH=750
WIN_HEIGHT=600
BORDER_SIZE=25
ICON="video-x-generic"
TITLE="Pardus ffmpeg Frontend"

# =========================================================
# 2. VİDEO DÖNÜŞTÜRME MODÜLÜ
# =========================================================
open_video_converter() {
    # Değişkenleri Başlat
    local input_file=""
    local format="mp4"
    local target_file=""
    
    # Varsayılan Arayüz Değerleri
    local quality_sel="Dengeli (Standart)"
    local res_sel="Orijinal"
    local no_audio="FALSE"

    # Geçici değişkenler
    local dashboard_output
    local exit_code
    local format_list
    local selected_file

    while true; do
        
        # Format Listesi
        format_list="^mp4!mkv!webm!avi!mov!flv"
        [[ "$format" == "mkv" ]]  && format_list="^mkv!mp4!webm!avi!mov!flv"
        [[ "$format" == "webm" ]] && format_list="^webm!mp4!mkv!avi!mov!flv"
        [[ "$format" == "avi" ]]  && format_list="^avi!mp4!mkv!mov!flv!webm"
        [[ "$format" == "mov" ]]  && format_list="^mov!mp4!mkv!avi!flv!webm"
        [[ "$format" == "flv" ]]  && format_list="^flv!mp4!mkv!avi!mov!webm"

        # Kalite Listesi
        local quality_list="En Yüksek!Yüksek!Standart!Küçük!En Küçük"

        # Otomatik İsimlendirme
        if [ -n "$input_file" ]; then
            local current_ext="${target_file##*.}"
            if [ -z "$target_file" ] || [ "$current_ext" != "$format" ]; then
                target_file="${input_file%.*}.${format}"
            fi
        fi

        # --- DASHBOARD ÇİZİMİ ---
        # Codec alanı çıkarıldı.
        # Yeni Sıralama: 
        # 1:Input | 2:Format | 3:Kalite | 4:Çözünürlük | 5:Ses | 6:Output
        
        dashboard_output=$(yad --form \
            --title="$TITLE - Video Dönüştürme" \
            --window-icon="$ICON" --center \
            --width=$WIN_WIDTH --height=$WIN_HEIGHT \
            --borders=$BORDER_SIZE \
            --separator="|" \
            --text="<span size='x-large' weight='bold' color='#2980b9'>Video Dönüştürme Stüdyosu</span>\n\nAyarları yapılandırıp işlemi başlatın." \
            --field="<b>Kaynak Dosya:</b>":RO "$input_file" \
            --field="<b>Hedef Format:</b>":CB "$format_list" \
            --field="<b>Kalite / Boyut:</b>":CB "$quality_list" \
            --field="<b>Çözünürlük:</b>":CB "^Orijinal!1080p!720p!480p" \
            --field="Videodaki Sesi Kaldır":CHK "$no_audio" \
            --field="<b>Çıktı Yolu:</b>":TXT "$target_file" \
            --button="Dosya Seç...!gtk-open:2" \
            --button="Ana Menü!gtk-home:3" \
            --button="Dönüştürmeyi Başlat!gtk-execute:0")
        
        exit_code=$?

        # --- VERİLERİ GERİ OKUMA ---
        # Sütun numaraları değiştiği için buraları güncelledik (cut -f...)
        local new_format=$(echo "$dashboard_output" | cut -d'|' -f2)
        local new_quality=$(echo "$dashboard_output" | cut -d'|' -f3) # Eskiden 4'tü
        local new_res=$(echo "$dashboard_output" | cut -d'|' -f4)     # Eskiden 5'ti
        local new_audio=$(echo "$dashboard_output" | cut -d'|' -f5)   # Eskiden 6'ydı
        local new_target=$(echo "$dashboard_output" | cut -d'|' -f6)  # Eskiden 7'ydi

        # Değişkenleri güncelle
        [ -n "$new_format" ] && format="$new_format"
        [ -n "$new_target" ] && target_file="$new_target"
        quality_sel="$new_quality"
        res_sel="$new_res"
        no_audio="$new_audio"

        # --- AKSİYONLAR ---

        # 1. Çıkış / Ana Menü
        if [ $exit_code -eq 3 ] || [ $exit_code -eq 252 ]; then
            return 
        fi

        # 2. Dosya Seçimi
        if [ $exit_code -eq 2 ]; then
            selected_file=$(yad --file \
                --title="Kaynak Dosya Seçin" \
                --window-icon="$ICON" --center \
                --width=$WIN_WIDTH --height=$WIN_HEIGHT --borders=$BORDER_SIZE \
                --file-filter="Videolar | *.mp4 *.mkv *.avi *.mov *.flv *.webm")
            
            if [ -n "$selected_file" ]; then
                input_file="$selected_file"
                target_file=""
            fi
            continue 
        fi

        # 3. Dönüştürme Başlat
        if [ $exit_code -eq 0 ]; then
            
            # Hata: Dosya Seçili Değil
            if [ -z "$input_file" ]; then
                yad --error --title="Hata" --center --text="Lütfen önce bir dosya seçin!" \
                    --borders=$BORDER_SIZE --button="Tamam:0"
                continue
            fi

            # Akıllı Uzantı Düzeltme
            local filename_no_ext="${target_file%.*}"
            local current_extension="${target_file##*.}"
            if [ "$current_extension" != "$format" ]; then
                target_file="${filename_no_ext}.${format}"
            fi

            # Çakışma Kontrolü (Kaynak == Hedef)
            if [ "$input_file" == "$target_file" ]; then
                yad --error --title="Hata" --center --borders=$BORDER_SIZE \
                    --text="Kaynak ve Hedef aynı olamaz!\nLütfen formatı değiştirin veya ismi düzenleyin." --button="Tamam:0"
                continue
            fi

            # Dosya Mevcut Kontrolü
            if [ -f "$target_file" ]; then
                if ! yad --question --title="Dosya Mevcut" --center --borders=$BORDER_SIZE \
                    --text="Dosya zaten var. Üzerine yazılsın mı?" --button="İptal:1" --button="Evet:0"; then
                    continue
                fi
            fi

            # İŞLEM BAŞLIYOR
            local duration=$(get_duration "$input_file")
            
            # Parametreler: input output duration quality resolution remove_audio
            convert_with_progress "$input_file" "$target_file" "$duration" "$quality_sel" "$res_sel" "$no_audio" | \
            yad --progress --title="İşlem Sürüyor" \
                --text="<span weight='bold'>Dönüştürülüyor...</span>\n$(basename "$target_file")" \
                --center --width=500 --auto-close --percentage=0 --borders=$BORDER_SIZE

            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                yad --info --title="Başarılı" --center --text="<span color='green' weight='bold'>İşlem Tamamlandı!</span>" \
                    --borders=$BORDER_SIZE --button="Tamam:0"
                return 
            else
                yad --error --title="Hata" --center --text="Bir hata oluştu!" --borders=$BORDER_SIZE
            fi
        fi
    done
}


# --- B. Video Bilgisi Modülü ---
open_media_info_tool() {
    local input_file=""
    # DÜZELTME: HTML etiketleri kaldırıldı. Sadece temiz metin.
    local info_text="\n\nHenüz bir dosya seçilmedi...\n\nLütfen detayları görmek için\n'Dosya Seç' butonuna basın."
    
    local dashboard_output
    local exit_code
    local selected_file

    while true; do
        # Bilgi Penceresi (Dashboard)
        dashboard_output=$(yad --form \
            --title="$TITLE - Medya Bilgisi" \
            --window-icon="dialog-information" --center \
            --width=$WIN_WIDTH --height=$WIN_HEIGHT \
            --borders=$BORDER_SIZE \
            --separator="|" \
            --text="<span size='x-large' weight='bold' color='#8e44ad'>Medya Bilgisi </span>\n\nDosyanın codec, bitrate ve çözünürlük bilgilerini görüntüleyin." \
            --field="Seçilen Dosya:":RO "$input_file" \
            --field="Detaylı Rapor:TXT" "$info_text" \
            --button="Dosya Seç...!gtk-open:2" \
            --button="Ana Menü!gtk-home:3")
        
        exit_code=$?

        # 1. Çıkış / Ana Menü
        if [ $exit_code -eq 3 ] || [ $exit_code -eq 252 ]; then
            return
        fi

        # 2. Dosya Seçimi
        if [ $exit_code -eq 2 ]; then
            selected_file=$(yad --file \
                --title="İncelenecek Dosyayı Seçin" \
                --window-icon="dialog-information" --center \
                --width=$WIN_WIDTH --height=$WIN_HEIGHT --borders=$BORDER_SIZE \
                --file-filter="Medya | *.mp4 *.mkv *.avi *.mov *.flv *.webm *.mp3 *.wav")
            
            if [ -n "$selected_file" ]; then
                input_file="$selected_file"
                
                # core.sh'tan raporu çek
                info_text=$(get_video_metadata "$input_file")
            fi
            continue
        fi
    done
}

# --- C. SES DÖNÜŞTÜRME MODÜLÜ ---
open_audio_converter() {
    local input_file=""
    local format="mp3"
    local target_file=""
    local bitrate="192k" 
    
    local dashboard_output
    local exit_code
    local selected_file
    
    while true; do
        # Format Listesi
        local format_list="^mp3!m4a (AAC)!flac (Kayıpsız)!wav (Ham)!ogg"
        local bitrate_list="320k (Yüksek Kalite)!^192k (Standart)!128k (Düşük/Konuşma)"

        # Otomatik İsimlendirme (Dashboard açılırken)
        if [ -n "$input_file" ]; then
            local current_ext="${target_file##*.}"
            # Format isminden sadece uzantıyı al (m4a (AAC) -> m4a)
            local clean_format=$(echo "$format" | awk '{print $1}')
            
            if [ -z "$target_file" ] || [ "$current_ext" != "$clean_format" ]; then
                target_file="${input_file%.*}.${clean_format}"
            fi
        fi

        # DASHBOARD
        dashboard_output=$(yad --form \
            --title="$TITLE - Ses Stüdyosu" \
            --window-icon="audio-x-generic" --center \
            --width=$WIN_WIDTH --height=$WIN_HEIGHT \
            --borders=$BORDER_SIZE \
            --separator="|" \
            --text="<span size='x-large' weight='bold' color='#d35400'>Ses Dönüştürme Stüdyosu 🎵</span>\n\nVideodan ses ayıklayın veya ses formatını değiştirin." \
            --field="<b>Kaynak Dosya:</b>":RO "$input_file" \
            --field="<b>Hedef Format:</b>":CB "$format_list" \
            --field="<b>Bitrate (Kalite):</b>":CB "$bitrate_list" \
            --field="<b>Çıktı Yolu:</b>":TXT "$target_file" \
            --button="Dosya Seç...!gtk-open:2" \
            --button="Ana Menü!gtk-home:3" \
            --button="Dönüştür!gtk-execute:0")
        
        exit_code=$?
        
        # Verileri Oku
        local new_format=$(echo "$dashboard_output" | cut -d'|' -f2)
        local new_bitrate=$(echo "$dashboard_output" | cut -d'|' -f3)
        local new_target=$(echo "$dashboard_output" | cut -d'|' -f4)

        if [ -n "$new_format" ]; then format=$(echo "$new_format" | awk '{print $1}'); fi
        if [ -n "$new_bitrate" ]; then bitrate=$(echo "$new_bitrate" | awk '{print $1}'); fi
        [ -n "$new_target" ] && target_file="$new_target"

        # AKSİYONLAR
        if [ $exit_code -eq 3 ] || [ $exit_code -eq 252 ]; then return; fi

        # Dosya Seçimi
        if [ $exit_code -eq 2 ]; then
            selected_file=$(yad --file \
                --title="Ses veya Video Dosyası Seçin" \
                --window-icon="audio-x-generic" --center \
                --width=$WIN_WIDTH --height=$WIN_HEIGHT --borders=$BORDER_SIZE \
                --file-filter="Medya | *.mp3 *.wav *.flv *.mp4 *.mkv *.avi *.mov *.m4a")
            
            if [ -n "$selected_file" ]; then
                input_file="$selected_file"
                target_file="" # Hedefi sıfırla
            fi
            continue
        fi

        # Dönüştürme
        if [ $exit_code -eq 0 ]; then
            if [ -z "$input_file" ]; then
                yad --error --title="Hata" --center --text="Dosya seçilmedi!" --borders=$BORDER_SIZE --button="Tamam:0"
                continue
            fi

            # --- AKILLI UZANTI DÜZELTME (Smart Extension Fix) ---
            # Kullanıcı formatı değiştirdiyse, hata vermeden önce uzantıyı biz düzeltiyoruz.
            local filename_no_ext="${target_file%.*}"
            local current_extension="${target_file##*.}"
            # Format değişkeni yukarıda zaten temizlenmişti (awk ile)
            
            if [ "$current_extension" != "$format" ]; then
                target_file="${filename_no_ext}.${format}"
            fi
            
            # --- Şimdi Kontrolleri Yap ---
            
            # Kaynak == Hedef Kontrolü
            if [ "$input_file" == "$target_file" ]; then
                # Tek buton yapıldı (Gereksiz git-gel olmasın)
                yad --error --title="Hata" --center --borders=$BORDER_SIZE \
                    --text="Kaynak ve Hedef aynı olamaz!\nLütfen formatı değiştirin veya ismi düzenleyin." \
                    --button="Tamam:0"
                continue
            fi

            if [ -f "$target_file" ]; then
                if ! yad --question --title="Dosya Mevcut" --center --text="Üzerine yazılsın mı?" --borders=$BORDER_SIZE --button="İptal:1" --button="Evet:0"; then continue; fi
            fi

            # İŞLEM
            local duration=$(get_duration "$input_file")
            convert_audio_with_progress "$input_file" "$target_file" "$duration" "$format" "$bitrate" | \
            yad --progress --title="Ses İşleniyor" --text="Dönüştürülüyor: $(basename "$target_file")" \
                --center --width=500 --auto-close --percentage=0 --borders=$BORDER_SIZE

            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                yad --info --title="Başarılı" --center --text="<span color='green'>Ses işlemi tamamlandı!</span>" --borders=$BORDER_SIZE --button="Tamam:0"
                return
            else
                yad --error --title="Hata" --center --text="Bir hata oluştu!" --borders=$BORDER_SIZE
            fi
        fi
    done
}

# =========================================================
# 3. ANA YÖNLENDİRİCİ
# =========================================================
run_gui() {
    local choice
    local exit_status

    while true; do
        # Menüye "INFO" seçeneği eklendi
        choice=$(yad --list \
            --title="$TITLE" \
            --window-icon="$ICON" --center \
            --width=$WIN_WIDTH --height=$WIN_HEIGHT --borders=$BORDER_SIZE \
            --text="<span size='x-large' weight='bold' color='#2c3e50'>Hoş Geldiniz!</span>\n\n<span size='large'>Lütfen bir işlem seçin:</span>" \
            --column="Kod":HD --column="İşlem Menüsü" \
            --hide-header --print-column=1 --separator="" \
            "CONVERT" "🎬  Video Dönüştürme Stüdyosu" \
            "AUDIO"   "🎵  Ses Dönüştürme" \
            "INFO"    "ℹ️   Dosya Bilgisi Göster" \
            --button="Seç!gtk-apply:0" \
            --button="Çıkış!application-exit:1")

        exit_status=$?
        if [ $exit_status -ne 0 ]; then break; fi
        if [ -z "$choice" ]; then continue; fi

        case "$choice" in
            "CONVERT") open_video_converter ;;
            "AUDIO")   open_audio_converter ;; 
            "INFO")    open_media_info_tool ;; 
        esac
    done
}