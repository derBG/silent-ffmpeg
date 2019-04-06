#!/bin/bash

# silent-ffmpeg.sh v0.5.1.0
# Little script for the recoding task of mkv video files
# Copyright Christian Lazzaro
# <c.lazzaro@linux.com>
# 2017
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

# Wo ist der Arbeitsordner dieses Scriptes?
FFMPEGSDIR="to be filled"

# Soll mkvmerge benutzt werden?
MERGE="1"

# Welche Formate sollen umgewandelt werden?
Formate="*.mkv"

# Verfügbare Encoder mittels `ffmpeg -encoders`
VCodec="libx264"

# Preset auswählen zum Kodieren je Langsamer desto bessere Qualität und geringerer Speicherbedarf.
# Das Preset placebo ist zwar noch ein qäuntchen besser, braucht aber 3x so viel Zeit wie veryslow.
# Zur Auswahl stehen:
# Ultrafast, superfast, veryfast,
# faster, fast, medium, slow,
# slower, veryslow, placebo
Preset="veryslow"

# Tune auswählen zur Auswahl stehen:
# film (reale Filme)
# animation (wie Tom&Jerry, echter Zeichentrick, nicht Computer animiert)
# grain (körniges Material wie zb der Film 300)
# stillimage (unbewegte Einzelbilder)
Tune="-tune grain"

# Bitraten einstellen für die verschiedenen Auflösungen
# Low = Breite zwischen 1 und 711
Avg_Low="1400k"
Min_Low="100k"
Max_Low="2400k"

#480p = Breite zwischen 712 und 1172
Avg_480p="1900k"
Min_480p="200k"
Max_480p="2900k"

# 720p = Breite zwischen 1173 und 1582
Avg_720p="2400k"
Min_720p="250k"
Max_720p="3600k"

# 1080p = Breite zwischen 1583 und 2000
Avg_1080p="3000k"
Min_1080p="350k"
Max_1080p="3850k"

# Audio Codec verfügbare Codecs mittels `ffmpeg -codecs`
ACodec="libfdk_aac"

# Audio Bitrate
ABit="384k"


#---------------------------------------------------------
# Ab hier nichts mehr ändern!
#---------------------------------------------------------
debug="0"

if [[ $debug == "0"  ]]; then exec 2>/dev/null ; fi

# Prüfungen ob die nötigen Programme und codecs vorhanden sind
mkvmerge -v 2>/dev/null >/dev/null
if [[ $? != 2 ]]; then
  echo "\nmkvmerge ist nicht installiert!\nBitte ändern! Breche nun ab.\n"
  exit 1
fi

ffmpeg -version 2>/dev/null >/dev/null
if [[ $? != 0 ]]; then
  echo "\nFFMPEG ist nicht installiert!\nBitte ändern! Breche nun ab.\n"
  exit 1
fi

ffmpeg -encoders  | grep ${VCodec} 2>/dev/null >/dev/null
if [[ $? != 0 ]]; then
  echo "\nFFMPEG hat nicht das ${VCodec} plugin!\nBitte ändern! Breche nun ab.\n"
  exit 1
fi

ffmpeg -encoders  | grep ${ACodec} 2>/dev/null >/dev/null
if [[ $? != 0 ]]; then
  echo "\nFFMPEG hat nicht das ${ACodec} plugin!\nBitte ändern! Breche nun ab.\n"
  exit 1
fi


# Ordner Deklarieren
MTODODIR="${FFMPEGSDIR}/1-Merge-todo"
MFAILDIR="${FFMPEGSDIR}/2-Merge-fail"
MDONEDIR="${FFMPEGSDIR}/3-Merge-done"
FTODODIR="${FFMPEGSDIR}/1-ffmpeg-todo"
FFAILDIR="${FFMPEGSDIR}/2-ffmpeg-fail"
FDONEDIR="${FFMPEGSDIR}/3-ffmpeg-done"
FREADYDIR="${FFMPEGSDIR}/4-ffmpeg-ready"

# Ordner erstellen
mkdir -p ${MREADYDIR} ${MDONEDIR} ${MFAILDIR} ${MTODODIR} ${FTODODIR} ${FTODODIR} ${FTODODIR}/encode ${FFAILDIR} ${FDONEDIR} ${FREADYDIR} || /bin/true

# Check ob das Script schon läuft um mehrfachausführungen zu verhindern
PID=`pidof -x silent-ffmpeg.sh`
#if [[ `echo $?` != 1 ]]; then
#  echo -e "\nEs wird bereits umgewandelt!\nDie PID lautet: ${PID}\nBreche nun ab!\n"
#fi

if [[ -e ${FFMPEGSDIR}/ffmpeg-recode.pid ]]; then
  echo -e "\n\nEs wird bereits schon umgewandelt!\nFalls nicht dann lösche die Datei \n${FFMPEGSDIR}/ffmpeg-recode.pid\n\n"
  exit 1
fi

touch ${FFMPEGSDIR}/ffmpeg-recode.pid
echo $PID > ${FFMPEGSDIR}/ffmpeg-recode.pid

# Nur wenn Merge=1 gesetzt ist dann mergen
if [[ $MERGE = 1 ]]; then

# Wechsel in den Arbeitsordner
cd ${MTODODIR}

# Schleife zum Mergen
  for D in ${MTODODIR}/*; do
    if [ -d ${D} ]; then
        cd ${D}
        # Auflistung des MkV Files
        MFILE=`ls -1 | grep mkv`
        # Merge Prozess
        mkvmerge -q -o ${FTODODIR}/${MFILE} ${D}/${MFILE}  ${D}/Subs/*${idx,sub}
        # Wenn erfolgreich verschieben in ffmpeg todo, wenn fehlerhaft verschieben in merge fail
        if [[ $? = 0 ]]; then
          mv  ${D} ${MDONEDIR}
        else
          mv ${D} ${MFAILDIR}
        fi
        cd ..
    fi
  done
fi

# Wechseln in den FFMPEG Arbeitsordner
cd ${FTODODIR}

# Prüfen ob überhaupt eine Datei zum Umwandeln da ist.
file=`ls -1 ${Formate} | head -n1`
if [[ -e "${file}" ]]; then
  sleep 1
else
  rm ${FFMPEGSDIR}/ffmpeg-recode.pid
  exit 1
fi

# Schleife für Ermittlung der Bitraten und beginn der Kodierung
  for i in  ${Formate};
   do
echo "In Schleife Tonspur"
  # Tonspuren ermitteln und mapping  setzen
    Tonspur_de=`ffprobe "${i}" -show_streams 2>&1 | grep -w 'ger\|deu' | grep ": Audio" | grep -w 'stereo\|5.1' | head -n1 | cut -d "#" -f2 | cut -b 1-3`;
    Tonspur_eng=`ffprobe "${i}" -show_streams 2>&1 | grep "(eng): Audio" | grep -w 'stereo\|5.1' | head -n1 | cut -d "#" -f2 | cut -b 1-3`;
    if [[ -n ${Tonspur_de}  ]]; then Map=" -map_chapters 0 -map 0:0 -metadata:s:v:0 language=ger -map ${Tonspur_de} -metadata:s:a:0 language=ger ";fi
    if [[ -n ${Tonspur_eng} ]]; then Map="${Map} -map ${Tonspur_eng} -metadata:s:a:1 language=eng" ; fi
    if [[ -z ${Map} ]]; then Map=" -map_chapters 0 -map 0:0 -metadata:s:v:0 language=ger -map  ${Tonspur_de} -metadata:s:a:1 language=ger " ;fi

    # Untertitel erhalten
    if [[ -n  `ffprobe -loglevel error -select_streams s -show_entries stream=index:stream_tags=language -of csv=p=0 "${i}" | head -n1` ]]; then
        Map="${Map} -map 0:s -c copy"
    fi

# Ermitteln der Breite des Videos und setzen der Bitrate
# 4k Filme werden auf FullHD herunter gerechnet
      width=`ffprobe -v error -of flat=s=_ -select_streams v:0 -show_entries stream=width "${i}" | cut -d '=' -f2`;
        if [ ${width} -ge 1  -a ${width} -le 711 ]; then  Avg=${Avg_Low}; Min=${Min_Low}; Max=${Max_Low};
          elif [ ${width} -ge 712  -a ${width} -le 1172 ]; then Avg=${Avg_480p}; Min=${Min_480p}; Max=${Max_480p};
          elif [ ${width} -ge 1173  -a ${width} -le 1582 ]; then Avg=${Avg_720p}; Min=${Min_720p}; Max=${Max_720p};
          elif [ ${width} -ge 1583  -a ${width} -le 2000 ]; then Avg=${Avg_1080p}; Min=${Min_1080p}; Max=${Max_1080p};
          elif [ ${width} -ge 2001  -a ${width} -le 3890 ]; then Avg=${Avg_1080p}; Min=${Min_1080p}; Max=${Max_1080p};
	         Scale="-vf scale=w=1920:h=1080:force_original_aspect_ratio=decrease";
        fi

# Eigentlicher Kodierungsprozess mit niedriger Priorität
if [[ $debug == "0"  ]]; then exec 2>&1 ; fi
        nice -19 ffmpeg  \
        -i "${i}"  \
        -y ${Map} \
        -c:v ${VCodec} \
        -preset ${Preset} \
        -b:v ${Avg} \
        -minrate ${Min} \
        -maxrate ${Max} \
        -bufsize 6500k \
        -profile:v high10 \
        -level 4.2 ${Tune} ${Scale} \
        -c:a ${ACodec} \
        -b:a ${ABit} \
        -stats \
        -profile:a aac_he \
        -cutoff 19k \
        -c:s copy \
        ${FTODODIR}/encode/"${i}";

    #    -v quiet
# Prüfung ob beide Dateien die gleiche Länge aufweisen bei abweichung größer 5 Sekunden -> Fail
if [[ $debug == "0"  ]]; then exec 2>/dev/null ; fi
		SRC=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${i}" 2>/dev/null | cut -d'.' -f1`
		DST=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ${FTODODIR}/encode/"${i}" 2>/dev/null | cut -d'.' -f1`
    SIZESRC=`du -b "${i}"  | cut -f1`
    SIZEDST=`du -b ${FTODODIR}/encode/"${i}"  | cut -f1`
    if [ `expr $SRC - $DST` -gt 5 ] || [ `expr $DST - $SRC` -gt 5 ] || [ `expr $SIZESRC / $SIZEDST` -gt 3 ]; then
        mkdir -p ${FFAILDIR}/done ${FFAILDIR}/encode 2>/dev/null;
			  mv "${i}"  ${FFAILDIR}/done/ 2>/dev/null;
			  mv  ${FTODODIR}/encode/"${i}" ${FFAILDIR}/encode/;
      else
	      mv "${i}"  ${FDONEDIR} 2>/dev/null;
	      mv ${FTODODIR}/encode/"${i}" ${FREADYDIR};
		fi
 done
    rm ${FFMPEGSDIR}/ffmpeg-recode.pid
exit 0

# Ideen für Weiterentwicklung
# - Variablen für Settings auslagern in eine .cf Datei
#   - Verschieben aus Extracted Ordner und dabei
#     - Prüfung auf Subs Ordner und verschieben in Merge
#       anderfalls in ffmpegtodo
#
#

# Changelog
# v0.5.1.0 - 22.02.2019
# - mkvmerge integriert um Subtitles dem File hinzuzufügen
# - neue Ordnerstruktur
# - Prüfungen ob alle nötigen Programme und Plugins vorhanden sind
# - PID auslesen statt pidfile, behebt neustart Problem
# - Prüfung ob Dateien unterschiedlich lang sind nun mit 5 Sekunden Differenz erlaubt
# - Prüfung ob Dateigröße um Faktor größer 3 ist, wenn ja -> Fail
# - FIX: Mapping verbesstert, erkennt nun auch Stereo / 5.1 gemischte files korrekt
#
# Vor v0.5.1.0 kein changelog geführt
#
#
