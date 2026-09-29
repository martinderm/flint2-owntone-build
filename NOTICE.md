# Hinweise zu Urheberrecht, Herkunft und Lizenz

## OwnTone (das Paket)

OwnTone wird von **Espen Jürgensen und Mitwirkenden** entwickelt und steht unter der
**GNU General Public License, Version 2 (GPL-2.0)**. Der vollständige Lizenztext liegt in
[`LICENSE`](LICENSE).

Dieses Repository verteilt ein **unverändertes, selbst kompiliertes Binary** von OwnTone 28.5.
Am OwnTone-Quellcode wurden **keine Änderungen** vorgenommen.

- Projekt: https://github.com/owntone/owntone-server
- Version: `28.5`
- Quell-Tarball: https://github.com/owntone/owntone-server/releases/download/28.5/owntone-28.5.tar.xz
- sha256: `c9ee0152dc488f782a25a68e72d24c109882bef3dd2914315fe499c8415fd898`

**Bezug des korrespondierenden Quellcodes (GPL-2.0 §3):** Der zum Binary passende Quellcode ist
der obige, unveränderte Upstream-Tarball der Version 28.5, gebaut mit dem in
[`recipe/BUILD.md`](recipe/BUILD.md) dokumentierten, vollständig offengelegten Rezept
(OpenWrt-SDK 21.02.7 für `mediatek/mt7622`). Auf Anfrage wird der Quellcode erneut
bereitgestellt; die Angebotsfrist beträgt drei Jahre ab Veröffentlichung dieser Version.

## OpenWrt-Paketdateien

Teile des Build-Rezepts und das Init-Skript stammen aus dem **OpenWrt-Paketfeed**
(`openwrt/packages`, Zweig `openwrt-23.05`, Verzeichnis `sound/owntone`):

- `recipe/owntone.Makefile` — © OpenWrt.org, GPL-2.0
- `files/owntone.init` — © 2014 OpenWrt.org, GPL-2.0, **angepasst**

Die Anpassung am Init-Skript ist im Abschnitt „Changes" unten dokumentiert.

## Änderungen gegenüber dem Upstream-Stand

| Datei | Änderung |
| :--- | :--- |
| `files/owntone.init` | `start()` legt `/var/cache/owntone` (tmpfs) an und setzt den Eigentümer auf `owntone`; `stop()` wartet 2 s, damit `restart` nicht mit „already running" abbricht. |
| `files/owntone-airplay.conf.snippet` | Neuschöpfung: `airplay "<Name>" { raop_disable = true }` zum Erzwingen von AirPlay 2. |
| `files/radio/*.m3u` | Neuschöpfung: Playlists mit öffentlichen Stream-URLs Dritter. |
| `recipe/BUILD.md`, `README.md` | Neuschöpfung: Dokumentation. |

Am OwnTone-Programm selbst (Quellcode) gibt es **keine** Änderungen.

## Nicht enthaltene Komponenten

Das Paket enthält **keine** Fremdbibliotheken. OwnTone bindet zur Laufzeit Bibliotheken,
die bereits Teil der GL.iNet-Firmware sind (u. a. FFmpeg-Bibliotheken, libsodium, libplist,
libgnutls, libwebsockets, sqlite). Diese werden hier **nicht mitverteilt**; es gelten die
Lizenzen des jeweiligen Firmware-Stands (FFmpeg z. B. LGPL-2.1-or-later / GPL-2.0-or-later).

## Marken und Dritte

GL.iNet, Flint 2, HomePod und Apple sind Marken der jeweiligen Inhaber.
Ö1 und FM4 sind Angebote des ORF, FIP ein Angebot von Radio France.

Dieses Projekt ist **inoffiziell** und steht in keiner Verbindung zu den genannten
Unternehmen und wird von ihnen nicht unterstützt oder beworben. Die in `files/radio/`
enthaltenen Stream-Adressen sind öffentlich verbreitete Angebote Dritter; an den
übertragenen Inhalten bestehen keine Rechte. Die Adressen können sich jederzeit ändern.

## Gewährleistung

Dieser Build wird **ohne jede Gewährleistung** bereitgestellt, insbesondere ohne
Zusicherung der Marktgängigkeit oder Eignung für einen bestimmten Zweck. Die Installation
erfolgt auf eigene Verantwortung.
