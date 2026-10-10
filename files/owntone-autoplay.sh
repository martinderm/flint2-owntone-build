#!/bin/sh
#
# OwnTone-Autostart: aktiviert einen AirPlay-Ausgang und startet einen Sender.
#
# Aufruf:  owntone-autoplay.sh [Ausgangsname] [Stream-URL] [Lautstaerke]
# Default: Wohnzimmer / OE1 / 30
#
# Wird beim Booten von /etc/init.d/owntone-autoplay im Hintergrund gestartet.
# Das Skript pollt, bis OwnTone laeuft und der Ausgang per mDNS gefunden wurde -
# die Startreihenfolge der Dienste spielt deshalb keine Rolle.

OUTPUT_NAME="${1:-Wohnzimmer}"
STATION_URL="${2:-https://orf-live.ors-shoutcast.at/oe1-q2a}"
VOLUME="${3:-30}"

API="http://127.0.0.1:3689/api"
TAG="owntone-autoplay"
MAXTRIES=60   # x 5 s = max. 5 Minuten

log() { logger -t "$TAG" "$1"; }

# --- 1) warten, bis OwnTone antwortet -------------------------------------
i=0
while [ "$i" -lt "$MAXTRIES" ]; do
	curl -s -o /dev/null -m 3 "$API/player" && break
	i=$((i + 1))
	sleep 5
done
if [ "$i" -ge "$MAXTRIES" ]; then
	log "OwnTone nicht erreichbar - abgebrochen"
	exit 1
fi
log "OwnTone erreichbar, suche Ausgang '$OUTPUT_NAME'"

# --- 2) Ausgang suchen (mDNS braucht nach dem Boot manchmal etwas) --------
i=0
ID=""
while [ "$i" -lt "$MAXTRIES" ]; do
	ID=$(curl -s -m 3 "$API/outputs" \
		| tr '{' '\n' \
		| grep "\"name\": \"$OUTPUT_NAME\"" \
		| sed -n 's/.*"id": "\([0-9]*\)".*/\1/p' \
		| head -1)
	[ -n "$ID" ] && break
	i=$((i + 1))
	sleep 5
done
if [ -z "$ID" ]; then
	log "Ausgang '$OUTPUT_NAME' nicht gefunden - abgebrochen"
	exit 1
fi
log "Ausgang '$OUTPUT_NAME' gefunden (id $ID)"

# --- 3) Lautstaerke setzen und Ausgang aktivieren -------------------------
BODY="{\"volume\":$VOLUME,\"selected\":true}"
curl -s -o /dev/null -m 10 -X PUT -H 'Content-Type: application/json' \
	-d "$BODY" "$API/outputs/$ID"
sleep 2
log "Ausgang aktiviert (volume $VOLUME)"

# --- 4) Sender starten ----------------------------------------------------
ENC=$(printf '%s' "$STATION_URL" \
	| sed -e 's|%|%25|g' -e 's|:|%3A|g' -e 's|/|%2F|g' \
	      -e 's|?|%3F|g' -e 's|=|%3D|g' -e 's|&|%26|g')

curl -s -o /dev/null -m 10 -X POST \
	"$API/queue/items/add?uris=$ENC&playback=start&clear=true"
sleep 3

STATE=$(curl -s -m 5 "$API/player" | sed -n 's/.*"state": "\([a-z]*\)".*/\1/p')
log "Sender gestartet: $STATION_URL (player state: $STATE)"
