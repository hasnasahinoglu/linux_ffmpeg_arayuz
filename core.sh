#!/bin/bash

get_duration() {
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1"
}

convert_with_progress() {
    local input_file="$1"
    local target_file="$2"
    local duration="$3"
    
    # Parametreler
    local quality_label="$4"    # Örn: "Orta (Standart)"
    local resolution="$5"       # Örn: "1080p"
    local remove_audio="$6"     # "TRUE" veya "FALSE"

    local cmd_options=""

    # --- 1. KALİTE AYARI (CRF) ---
    case "$quality_label" in
        *"Görsel Kayıpsız"*) cmd_options+="-crf 18 -preset slow " ;;
        *"Yüksek Kalite"*)   cmd_options+="-crf 20 -preset medium " ;;
        *"Dengeli"*)         cmd_options+="-crf 23 -preset medium " ;; 
        *"Küçük Boyut"*)     cmd_options+="-crf 28 -preset fast " ;;
        *"Arşivlik"*)        cmd_options+="-crf 35 -preset veryfast " ;;
        *)                   cmd_options+="-crf 23 " ;;
    esac

    # --- 2. ÇÖZÜNÜRLÜK AYARI ---
    if [ "$resolution" != "Orijinal" ] && [ -n "$resolution" ]; then
        if [ "$resolution" == "1080p" ]; then cmd_options+="-vf scale=-2:1080 "; fi
        if [ "$resolution" == "720p" ]; then cmd_options+="-vf scale=-2:720 "; fi
        if [ "$resolution" == "480p" ]; then cmd_options+="-vf scale=-2:480 "; fi
    fi

    # --- 3. SES AYARI (KRİTİK DÜZELTME BURADA) ---
    if [ "$remove_audio" == "TRUE" ]; then
        cmd_options+="-an "
    else
        # Hedef dosyanın uzantısını kontrol et
        if [[ "$target_file" == *".webm" ]]; then
            # WebM sadece Opus veya Vorbis sever. Opus daha moderndir.
            cmd_options+="-c:a libopus "
        elif [[ "$target_file" == *".avi" ]]; then
            # AVI, AAC ile bazen sorun çıkarabilir, MP3 (libmp3lame) AVI için garantidir.
            cmd_options+="-c:a libmp3lame "
        else
            # MP4, MKV, MOV için AAC standarttır ve güvenlidir.
            cmd_options+="-c:a aac "
        fi
    fi

    # Komutu Çalıştır
    ffmpeg -i "$input_file" -y -loglevel error -progress pipe:1 \
           -movflags +faststart -pix_fmt yuv420p \
           $cmd_options \
           "$target_file" | while read -r line; do
        if [[ $line =~ out_time_ms=([0-9]+) ]]; then
            local current_ms=${BASH_REMATCH[1]}
            local current_s=$(echo "scale=2; $current_ms / 1000000" | bc)
            local percent=$(echo "scale=0; ($current_s * 100 / $duration)" | bc)
            [ "$percent" -gt 100 ] && percent=100
            echo "$percent"
        fi
    done
}

# --- VİDEO BİLGİSİ ÇEKME FONKSİYONU ---
get_video_metadata() {
    local input_file="$1"

    if [ ! -f "$input_file" ]; then
        echo "Dosya bulunamadı."
        return
    fi

    # 1. Temel Dosya Bilgileri
    local filename=$(basename "$input_file")
    local size_bytes=$(stat -c%s "$input_file")
    
    # Boyutu otomatik ayarla (Örn: 500K, 12M, 1.5G)
    # Eğer numfmt yoksa (bazı minimal sistemlerde), eski usül hesaplayalım:
    local size_human=""
    if command -v numfmt &> /dev/null; then
        size_human=$(numfmt --to=iec-i --suffix=B "$size_bytes")
    else
        # Yedek yöntem (MB cinsinden)
        size_human="$(echo "scale=2; $size_bytes / 1024 / 1024" | bc) MB"
    fi
    
    # 2. ffprobe ile Teknik Detaylar
    local video_info=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=codec_name,width,height,avg_frame_rate,bit_rate \
        -of default=noprint_wrappers=1:nokey=1 "$input_file")
    
    local v_codec=$(echo "$video_info" | sed -n '1p')
    local width=$(echo "$video_info" | sed -n '2p')
    local height=$(echo "$video_info" | sed -n '3p')
    local fps_raw=$(echo "$video_info" | sed -n '4p')
    local v_bitrate=$(echo "$video_info" | sed -n '5p')

    # FPS Hesaplama
    local fps=$(echo "scale=2; $fps_raw" | bc 2>/dev/null)
    
    # Bitrate (Sadece sayı varsa işlem yap)
    local bitrate_kbps="Bilinmiyor"
    if [[ "$v_bitrate" =~ ^[0-9]+$ ]]; then
        bitrate_kbps="$((v_bitrate / 1000)) kbps"
    fi

    # Ses Bilgileri
    local audio_info=$(ffprobe -v error -select_streams a:0 \
        -show_entries stream=codec_name,sample_rate \
        -of default=noprint_wrappers=1:nokey=1 "$input_file")
    
    local a_codec=$(echo "$audio_info" | sed -n '1p')
    local a_sample=$(echo "$audio_info" | sed -n '2p')

    # Süre
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file")
    local duration_formatted="Bilinmiyor"
    if [ -n "$duration" ]; then
        duration_formatted=$(date -u -d @${duration%.*} +%H:%M:%S 2>/dev/null)
    fi

    # 3. Rapor Çıktısı (Temiz Metin)
    echo "================================================="
    echo "             DOSYA RAPORU"
    echo "================================================="
    echo "Dosya  : $filename"
    echo "Boyut  : $size_human"
    echo "Süre   : $duration_formatted"
    echo ""
    echo "[ VİDEO ]"
    echo "Çözünürlük : ${width}x${height}"
    echo "Codec      : $v_codec"
    echo "Kare Hızı  : $fps FPS"
    echo "Bitrate    : $bitrate_kbps"
    echo ""
    echo "[ SES ]"
    if [ -n "$a_codec" ]; then
        echo "Codec      : $a_codec"
        echo "Örnekleme  : $a_sample Hz"
    else
        echo "Ses izi bulunamadı."
    fi
    echo "================================================="
}

# --- SES DÖNÜŞTÜRME FONKSİYONU ---
convert_audio_with_progress() {
    local input_file="$1"
    local target_file="$2"
    local duration="$3"
    
    # Parametreler
    local format="$4"      # mp3, aac, flac, wav
    local bitrate="$5"     # 320k, 192k, 128k (WAV/FLAC için önemsiz olabilir)

    local cmd_options="-vn " # -vn: Video verisini yoksay (Sadece ses)

    # 1. Codec ve Format Ayarı
    case "$format" in
        "mp3")  cmd_options+="-c:a libmp3lame -b:a $bitrate " ;;
        "m4a")  cmd_options+="-c:a aac -b:a $bitrate " ;; # AAC codec
        "ogg")  cmd_options+="-c:a libvorbis -q:a 4 " ;; # Ogg için değişken kalite
        "flac") cmd_options+="-c:a flac " ;; # Kayıpsız, bitrate parametresi almaz
        "wav")  cmd_options+="-c:a pcm_s16le " ;; # Kayıpsız ham ses
        *)      cmd_options+="-c:a libmp3lame -b:a 192k " ;; # Varsayılan
    esac

    # Komutu Çalıştır
    ffmpeg -i "$input_file" -y -loglevel error -progress pipe:1 \
           $cmd_options \
           "$target_file" | while read -r line; do
        if [[ $line =~ out_time_ms=([0-9]+) ]]; then
            local current_ms=${BASH_REMATCH[1]}
            local current_s=$(echo "scale=2; $current_ms / 1000000" | bc)
            local percent=$(echo "scale=0; ($current_s * 100 / $duration)" | bc)
            [ "$percent" -gt 100 ] && percent=100
            echo "$percent"
        fi
    done
}