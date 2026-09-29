# OwnTone 28.5 für GL.iNet Flint 2 (GL-MT6000)

[![License: GPL-2.0](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](LICENSE)
[![Device](https://img.shields.io/badge/device-GL--MT6000%20%7C%20Flint%202-informational)](#kompatibilität)
[![Firmware](https://img.shields.io/badge/firmware-GL.iNet%204.11-orange)](#kompatibilität)
[![Architecture](https://img.shields.io/badge/arch-aarch64__cortex--a53-lightgrey)](#kompatibilität)
[![Package](https://img.shields.io/badge/ipk-owntone%2028.5--1-success)](#installation)
[![Warranty](https://img.shields.io/badge/warranty-none-critical)](#lizenz-und-hinweise)

**Inoffizieller Community-Build von [OwnTone](https://github.com/owntone/owntone-server) 28.5 für den GL.iNet Flint 2 (GL-MT6000) mit GL.iNet-Firmware 4.11.** Macht den Router zum dauerhaft laufenden Internetradio-Sender per **AirPlay 2** — z. B. Ö1 direkt auf einen HomePod, ohne iPhone/iPad/Mac im Audiopfad.

<details>
<summary><b>English summary</b></summary>

Unofficial community build of OwnTone 28.5 (AirPlay 2 / DAAP / MPD media server) for the GL.iNet Flint 2 (GL-MT6000) running GL.iNet firmware 4.11 (OpenWrt 21.02, `aarch64_cortex-a53`). Ships an installable `.ipk`, the full build recipe and internet radio playlists. It replaces the outdated `forked-daapd 27.2` from the GL.iNet feed, which can no longer connect to AirPlay 2 devices such as the HomePod. Not affiliated with or endorsed by GL.iNet, Apple or the OwnTone project. Install instructions below are in German — see [`recipe/BUILD.md`](recipe/BUILD.md) for the build recipe.

</details>

## Warum dieses Paket

Im GL.iNet-Paketfeed steckt für den Flint 2 nur **`forked-daapd 27.2`**. Diese Version kennt AirPlay 2 noch nicht: Sie erkennt den HomePod per mDNS, scheitert beim Verbinden aber an der alten Geräteverifikation (`403 Forbidden`, `Device verification`). Der passende eigene Build von **OwnTone 28.5** löst genau das.

| | `forked-daapd 27.2` (Feed) | Dieser Build |
| :--- | :--- | :--- |
| AirPlay 2 | ✗ | ✓ |
| HomePod-Verbindung | ✗ (`403` bei der Geräteverifikation) | ✓ (mit passender Home-App-Freigabe) |
| Web-UI im Paket | ✗ (fehlt) | ✓ |
| AirPlay-2-Passwort-Auth | ✗ | ✓ |

## Funktionsumfang

- AirPlay-2-Ausgabe (Datenbank liegt vollständig im RAM, keine Schreiblast auf der eMMC)
- Internetradio über m3u-Playlists, Web-UI auf Port `3689`, JSON-API, MPD auf `6600`
- Läuft als unprivilegierter Benutzer `owntone`, Autostart aktiv
- Nutzt ausschließlich Libraries, die die GL.iNet-4.11-Firmware bereits mitbringt — **keine** zusätzlichen Abhängigkeiten

## Kompatibilität

| | |
| :--- | :--- |
| Gerät | GL.iNet Flint 2 / GL-MT6000 |
| Firmware | GL.iNet **4.11** (OpenWrt 21.02-SNAPSHOT, `mediatek/mt7986`) |
| Architektur | `aarch64_cortex-a53`, gcc 8.4.0 / musl |
| Paket | `owntone 28.5-1` (724 KB, inkl. Web-UI) |

Andere GL.iNet-Modelle oder Firmwarestände sind **nicht getestet**. Da es sich um ein reines Userspace-Paket ohne Kernelmodule handelt, ist es ABI-verträglich mit jedem OpenWrt-21.02-System auf `aarch64_cortex-a53`.

## Installation

Alle Befehle auf dem Router per SSH als `root`.

### 1. Dateien übertragen

```sh
# vom eigenen Rechner aus, in der Repo-Wurzel:
scp -O ipk/owntone_28.5-1_aarch64_cortex-a53.ipk root@<router>:/tmp/
scp -O files/owntone.init files/owntone-airplay.conf.snippet files/api-select-output.json root@<router>:/tmp/
```

> `-O` ist zwingend: Dropbear hat keinen SFTP-Server, moderne `scp`-Clients scheitern sonst mit `sftp-server: not found`.

Integrität prüfen (optional):

```sh
sha256sum /tmp/owntone_28.5-1_aarch64_cortex-a53.ipk
# D832CF52E00A67443FA1011A0990D9BFB5C6C4CB89B1AFC97161AA0D3F57A664
```

### 2. Benutzer anlegen

```sh
grep -q '^owntone:' /etc/group  || echo 'owntone:x:501:' >> /etc/group
grep -q '^owntone:' /etc/passwd || echo 'owntone:x:501:501:owntone:/var/run/owntone:/bin/false' >> /etc/passwd
```

### 3. Paket installieren

```sh
opkg install /tmp/owntone_28.5-1_aarch64_cortex-a53.ipk
```

### 4. Init-Skript und Konfiguration

```sh
cp /tmp/owntone.init /etc/init.d/owntone
chmod 755 /etc/init.d/owntone
```

Das gepatchte Init-Skript legt bei jedem Start `/var/cache/owntone` an (Datenbank im tmpfs) und wartet beim Stoppen kurz, damit `restart` zuverlässig läuft.

Konfiguration setzen — Skript übernimmt alles Nötige (idempotent, fragt optional das AirPlay-Passwort verdeckt ab):

```sh
sh /tmp/configure-owntone.sh Wohnzimmer
```

> `Wohnzimmer` durch den eigenen AirPlay-Namen ersetzen. Das Skript legt den `airplay`-Block an, setzt `raop_disable = true` (erzwingt AirPlay 2), trägt den nötigen `user_agent` ein und startet den Dienst neu.

Manuell entspricht das:

```
# in der general-Sektion:
user_agent = "AirPlay/540.31"

# am Dateiende:
airplay "Wohnzimmer" {
	raop_disable = true
	# Lautstärke-Obergrenze (OwnTone-Skala bis 11) - sinnvoll als Schutz
	max_volume = 3
	# Nur setzen, wenn in der Home-App "Require Password" aktiv ist.
	# Derzeit nicht empfohlen, siehe "Bekanntes Problem".
#	password = "<passwort>"
}
```

## Verifiziert

Ende-zu-Ende getestet auf Flint 2 (Firmware 4.11) mit HomePod (OS 27): Ö1 → OwnTone → AirPlay 2 → HomePod, inklusive automatischem Reconnect nach kurzen Verbindungsabbrüchen (`Attempting reconnection in 5 sec`, der Stream läuft weiter). Voraussetzungen: Home-App-Freigabe „Anyone on the Same Network", `user_agent` gesetzt und kein Passwort aktiv.

**Warum der `user_agent` nötig ist:** Ab HomePod-Generation/OS 27 beantwortet der HomePod ein `GET /info` mit **403**, wenn der absendende Client keinen Apple-artigen User-Agent schickt. OwnTone sendet per Default `owntone/28.5` — damit kommt keine Verbindung zustande. `AirPlay/540.31` (oder `iTunes/12.9`) wird akzeptiert.

### 5. Dienst starten

```sh
/etc/init.d/owntone enable
/etc/init.d/owntone start

ps w | grep '[o]wntone'
wget -qO- http://127.0.0.1:3689/api/outputs
```

### 6. Radio-Sender anlegen

OwnTone bringt keine Sender mit — Sender sind m3u-Playlists mit Stream-URLs in `/srv/music`. Fertige Vorlagen liegen in [`files/radio/`](files/radio).

```sh
# Linux/macOS, in der Repo-Wurzel:
tar -cf /tmp/radio.tar -C files/radio . && scp -O /tmp/radio.tar root@<router>:/tmp/
```

```powershell
# Windows PowerShell:
tar -cf tmp\radio.tar -C files\radio . ; scp -O tmp\radio.tar root@<router>:/tmp/
```

```sh
# auf dem Router:
mkdir -p /srv/music
tar -xf /tmp/radio.tar -C /srv/music
chown -R owntone:owntone /srv/music
```

Damit die Sender auch unter „Playlists" auftauchen (statt nur in der Radio-Bibliothek), in `/etc/owntone.conf` ergänzen:

```
radio_playlists = true
```

Rescan anstoßen:

```sh
curl -X PUT http://127.0.0.1:3689/api/rescan
curl -s http://127.0.0.1:3689/api/library/playlists    # pro Sender "stream_count": 1
```

### 7. Web-UI öffnen

```
http://<router-ip>:3689
```

Aus anderen Netzen (VPN/Tailnet) antwortet 28.5 mit `403 Forbidden`, weil `trusted_networks` standardmäßig nur `localhost`, `192.168` und `fd` zulässt. Freischalten:

```
trusted_networks = { "localhost", "192.168", "fd", "100." }
```

```sh
/etc/init.d/owntone restart
```

## Enthaltene Sender-Vorlagen

| Sender | Quelle | Format |
| :--- | :--- | :--- |
| OE1 | `orf-live.ors-shoutcast.at/oe1-q2a` | MP3 192 kbps |
| FM4 | `orf-live.ors-shoutcast.at/fm4-q2a` | MP3 192 kbps |
| FIP, FIP Pop, FIP Rock, FIP Jazz, FIP Groove, FIP Electro, FIP Metal, FIP Hip-Hop, FIP Reggae, FIP World, FIP Nouveautés | `icecast.radiofrance.fr/<mount>-hifi.aac?id=radiofrance` | AAC 192 kbps (höchste angebotene Qualität) |

Eigene Sender: eine `.m3u`-Datei genügt.

```
#EXTM3U
#EXTINF:-1,Ö1
https://orf-live.ors-shoutcast.at/oe1-q2a
```

Die URLs sind Angebote Dritter (ORF, Radio France), können sich jederzeit ändern und begründen keine Rechte an den Inhalten.

## Bekanntes Problem: HomePod-Ausgabe lässt sich nicht aktivieren

Der HomePod stellt **drei** Hürden. Die Log-Meldung (`/var/log/owntone.log`) zeigt, an welcher es hängt:

| Log-Meldung | Ursache | Lösung |
| :--- | :--- | :--- |
| `Response to GET /info (probe) ... 403 Forbidden` | Zugriffsfreigabe in der Home-App zu restriktiv | Home-App → Home-Einstellungen → **Speaker & TV** → **„Anyone on the Same Network"** (oder „Everyone") |
| dieselbe `403`, obwohl die Freigabe gesetzt ist | OwnTone sendet `owntone/28.5` als User-Agent — HomePod OS 27 lehnt das ab | `user_agent = "AirPlay/540.31"` in der `general`-Sektion |
| `requires password authentication, but none given in config` | In der Home-App ist „Require Password" aktiv | Entweder `password = "…"` in den `airplay`-Block eintragen — oder „Require Password" ausschalten (siehe nächste Zeile) |
| `Pairing step 2 … authentication failure` bzw. `Response to SETUP (session) … 401 Unauthorized` | Passwort-Modus passt nicht zusammen (Home-App ohne Passwort, Config mit `password` — oder umgekehrt) | **Funktionierend verifiziert ist: „Require Password" in der Home-App aus + kein `password` in der Config** (Transient Pairing) |

> Mit gesetztem Passwort läuft das Pairing (HAP) zwar an, der HomePod OS 27 weist die Session danach aber mit `401` zurück und OwnTone verwirft die Schlüssel — daher derzeit **ohne** Passwort betreiben.

Aktivieren und prüfen:

```sh
curl -s -X PUT -H 'Content-Type: application/json' \
  -d @/tmp/api-select-output.json \
  http://127.0.0.1:3689/api/outputs/<output-id>
```

`204 No Content` = Ausgabe aktiv. Die ID liefert `GET /api/outputs`.

`sh /tmp/configure-owntone.sh <Name>` richtet `user_agent`, den `airplay`-Block und optional das Passwort in einem Schritt ein.

## Troubleshooting

| Symptom | Ursache / Lösung |
| :--- | :--- |
| Dienst startet nicht, Log `Could not open '/var/cache/owntone/...'` | Cache-Verzeichnis fehlt → gepatchtes Init aus `files/owntone.init` verwenden |
| Log `Could not stat() web root directory` | Web-Dateien fehlen (nicht bei diesem Build — Paket enthält `htdocs`) |
| Auswahl des HomePods endet mit `500` | Home-App-Freigabe, `user_agent` oder Passwort — Log-Meldung zuordnen, siehe „Bekanntes Problem" |
| Kein Ton / falsches Gerät | HomePod in der Ausgabeliste prüfen, ggf. `raop_disable` gesetzt? |
| `scp` bricht ab (`Connection closed`) | `-O` fehlt (Dropbear ohne SFTP) |
| Web-UI von außen `403` | `trusted_networks` erweitern (siehe oben) |

Log: `/var/log/owntone.log`

## Deinstallation

```sh
/etc/init.d/owntone stop
/etc/init.d/owntone disable
opkg remove owntone
rm -rf /var/cache/owntone /srv/music
```

Der Benutzer `owntone` bleibt in `/etc/passwd`/`/etc/group` und muss bei Bedarf manuell entfernt werden.

## Nach einem Firmware-Update

Mit „Keep Settings" bleiben die `/etc`-Änderungen und die Sender in `/srv/music` erhalten, das Paket wird jedoch entfernt — Schritte 1–5 erneut ausführen.

## Repository-Struktur

```
ipk/       Installierbares Paket + SHA256
recipe/    BUILD.md (komplette Bauanleitung), owntone.Makefile
files/     owntone.init, Config-Snippet, API-Body, radio/*.m3u
```

## Lizenz und Hinweise

Dieses Projekt steht unter der **GNU General Public License v2.0** — siehe [`LICENSE`](LICENSE). OwnTone ist ein Projekt von [Espen Jürgensen und Mitwirkenden](https://github.com/owntone/owntone-server); am Quellcode wurden keine Änderungen vorgenommen. Herkunft, Quellcode-Bezug und Markenhinweise: [`NOTICE.md`](NOTICE.md).

- Das Paket enthält **nur OwnTone-Dateien**. Laufzeit-Abhängigkeiten (u. a. FFmpeg) sind Teil der GL.iNet-Firmware und werden hier nicht mitverteilt.
- GL.iNet, Flint 2, HomePod und Apple sind Marken der jeweiligen Inhaber. Ö1 und FM4 sind Angebote des ORF, FIP ein Angebot von Radio France. Dieses Projekt ist **inoffiziell** und steht in keiner Verbindung zu ihnen.
- Bereitstellung **ohne jede Gewährleistung**; Installation auf eigene Verantwortung.
