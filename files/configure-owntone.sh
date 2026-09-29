#!/bin/sh
# Richtet /etc/owntone.conf für den Betrieb mit einem HomePod ein.
#
#  1. user_agent  – HomePod OS 27 lehnt den OwnTone-Standard-UA ("owntone/28.5")
#                   mit HTTP 403 auf GET /info ab; ein Apple-artiger UA wird akzeptiert.
#  2. airplay-Block mit raop_disable = true – erzwingt AirPlay 2 statt RAOP.
#  3. optional: AirPlay-Passwort (verdeckte Eingabe, landet nicht in der History).
#
# Aufruf:  sh configure-owntone.sh [HomePod-Name]
# Ohne Namen wird "Wohnzimmer" verwendet.

CONF=/etc/owntone.conf
NAME="${1:-Wohnzimmer}"
UA="AirPlay/540.31"

[ -f "$CONF" ] || { echo "Nicht gefunden: $CONF"; exit 1; }
cp "$CONF" "$CONF.bak.$(date +%Y%m%d-%H%M%S)"

# --- 1) user_agent in der general-Sektion --------------------------------
if grep -qE '^[[:space:]]*user_agent' "$CONF"; then
	sed -i 's|^[[:space:]]*user_agent.*|user_agent = "'"$UA"'"|' "$CONF"
else
	awk -v ua="$UA" '
		!done && /^general \{/ { print; print "user_agent = \"" ua "\""; done=1; next }
		{ print }
	' "$CONF" > "$CONF.new" && mv "$CONF.new" "$CONF"
fi

# --- 2) airplay-Block sicherstellen --------------------------------------
if ! grep -q "^airplay \"$NAME\"" "$CONF"; then
	printf '\nairplay "%s" {\n\traop_disable = true\n}\n' "$NAME" >> "$CONF"
fi

# --- 3) Passwort (optional) ---------------------------------------------
printf 'AirPlay-Passwort für "%s" (leer lassen = keines): ' "$NAME"
stty -echo 2>/dev/null
read PW
stty echo 2>/dev/null
echo

if [ -n "$PW" ]; then
	awk -v name="$NAME" -v pw="$PW" '
		index($0, "airplay \"" name "\"") == 1 { inblk=1; print; next }
		inblk && $0 == "}" { print "\tpassword = \"" pw "\""; print; inblk=0; next }
		inblk && index($0, "password") > 0 { next }
		{ print }
	' "$CONF" > "$CONF.new" && mv "$CONF.new" "$CONF"
	chown root:owntone "$CONF" 2>/dev/null
	chmod 640 "$CONF"
	echo "Passwort in $CONF eingetragen."
else
	# Ohne Passwort erwartet der HomePod Transient Pairing: ein verbliebener
	# password-Eintrag führt sonst zu "authentication failure" (Pairing step 2)
	# bzw. "401 Unauthorized" auf SETUP (session).
	sed -i '/^[[:space:]]*password = /d' "$CONF"
	echo "Kein Passwort gesetzt - vorhandener Eintrag (falls vorhanden) entfernt."
fi

if /etc/init.d/owntone restart >/dev/null 2>&1; then
	echo "OwnTone neu gestartet."
else
	echo "WARNUNG: OwnTone-Neustart fehlgeschlagen."
fi
