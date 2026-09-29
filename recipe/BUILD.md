# OwnTone 28.5 für GL.iNet Flint 2 (GL-MT6000), Firmware 4.11

Bauanleitung für das Paket in [`../ipk/`](../ipk/). Alle Pfade sind relativ zum Repo-Wurzelverzeichnis.

## Artefakt

| Feld | Wert |
| :--- | :--- |
| Datei | `ipk/owntone_28.5-1_aarch64_cortex-a53.ipk` (724 KB, inkl. Web-UI) |
| sha256 | `D832CF52E00A67443FA1011A0990D9BFB5C6C4CB89B1AFC97161AA0D3F57A664` |
| Ziel | GL.iNet 4.11 (OpenWrt 21.02-SNAPSHOT), mediatek/mt7986, `aarch64_cortex-a53` |
| Zweck | AirPlay-2-Sender für Internetradio → HomePod; ersetzt `forked-daapd 27.2` aus dem GL.iNet-Feed |

## Warum dieses SDK

GL.iNet 4.11 basiert auf OpenWrt 21.02 (gcc 8.4.0, musl 1.1.24). Für `mediatek/mt7986` gibt es kein offizielles 21.02-SDK; **`mediatek/mt7622` ist ebenfalls `aarch64_cortex-a53` mit identischer ABI**. Da OwnTone ein reines Userspace-Paket ohne kmod-Abhängigkeiten ist, ist das SDK-Paket dort lauffähig.

## Bauen (WSL2 Ubuntu, 8 Kerne)

```sh
# 1) SDK holen
mkdir -p ~/sdk-dl && cd ~/sdk-dl
wget -O sdk.tar.xz \
  https://downloads.openwrt.org/releases/21.02.7/targets/mediatek/mt7622/openwrt-sdk-21.02.7-mediatek-mt7622_gcc-8.4.0_musl.Linux-x86_64.tar.xz
sha256sum sdk.tar.xz   # erwartet: 723b08a90778779cbc20da03a36fa0e213b22dd63ce601803f0eae44f303681d
mkdir -p ~/owntone-build && tar -xJf sdk.tar.xz -C ~/owntone-build
cd ~/owntone-build/openwrt-sdk-21.02.7-mediatek-mt7622_gcc-8.4.0_musl.Linux-x86_64

# 2) Feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 3) Paketdateien (Upstream openwrt/packages, Zweig openwrt-23.05)
mkdir -p package/owntone/files
cp <repo>/recipe/owntone.Makefile package/owntone/Makefile
curl -o package/owntone/files/owntone.init  https://raw.githubusercontent.com/openwrt/packages/openwrt-23.05/sound/owntone/files/owntone.init
curl -o package/owntone/files/owntone.conf  https://raw.githubusercontent.com/openwrt/packages/openwrt-23.05/sound/owntone/files/owntone.conf
# Hinweis: Im Paket steckt die Upstream-Init; auf dem Gerät wird die gepatchte
# Variante aus files/owntone.init verwendet (legt das tmpfs-Cache-Verzeichnis an).

# 4) Konfigurieren
make defconfig          # legt .config an (Ziel steht fest)
sed -i 's/^CONFIG_ALL=y/# CONFIG_ALL is not set/' .config
sed -i 's/^CONFIG_ALL_KMODS=y/# CONFIG_ALL_KMODS is not set/' .config
sed -i 's/^CONFIG_ALL_NONSHARED=y/# CONFIG_ALL_NONSHARED is not set/' .config
echo 'CONFIG_PACKAGE_owntone=m' >> .config
make defconfig

# 5) Bauen (baut Abhängigkeiten mit: ffmpeg-full, gnutls, protobuf, libsodium, ...)
make -j8 package/owntone/compile V=s

# Ergebnis
ls bin/packages/aarch64_cortex-a53/base/owntone_28.5-1_aarch64_cortex-a53.ipk
```

**Stolperfallen:** `CONFIG_ALL=y` ist im SDK-Default aktiv und baut sonst die komplette `world` (valgrind, socat, …). Ohne das Flag dauert der Build ~35 min auf 8 Kernen (ffmpeg ist der Lange).

## Radio-Sender anlegen

OwnTone bringt keine Sender mit. Sender sind **Playlists mit Stream-URLs** im Bibliotheksverzeichnis (`/srv/music`). Vorlagen liegen unter `files/radio/`.

### Enthaltene Sender (13)

| Sender | Quelle | Format |
| :--- | :--- | :--- |
| OE1 | `orf-live.ors-shoutcast.at/oe1-q2a` | MP3 192 kbps |
| FM4 | `orf-live.ors-shoutcast.at/fm4-q2a` | MP3 192 kbps |
| FIP, FIP Pop, FIP Rock, FIP Jazz, FIP Groove, FIP Electro, FIP Metal, FIP Hip-Hop, FIP Reggae, FIP World, FIP Nouveautés | `icecast.radiofrance.fr/<mount>-hifi.aac?id=radiofrance` | AAC 192 kbps (höchste angebotene Qualität) |

1. m3u-Datei anlegen (Format wie in `files/radio/`):

```
#EXTM3U
#EXTINF:-1,Ö1
https://orf-live.ors-shoutcast.at/oe1-q2a
```

2. Übertragen — alle Sender auf einmal, ohne SFTP (Dropbear kann kein SFTP):

```powershell
tar -cf tmp\radio.tar -C files\radio .
scp -O tmp\radio.tar root@<router>:/tmp/
ssh root@<router> "mkdir -p /srv/music && tar -xf /tmp/radio.tar -C /srv/music && chown -R owntone:owntone /srv/music && rm /tmp/radio.tar"
```

3. `radio_playlists = true` in `/etc/owntone.conf` sorgt dafür, dass Sender **auch** unter „Playlists" erscheinen (Default: nur „Radio"-Bibliothek).

4. Rescan anstoßen (oder Dienst neu starten):

```sh
curl -X PUT http://127.0.0.1:3689/api/rescan
curl -s http://127.0.0.1:3689/api/library/playlists   # muss "stream_count": 1 zeigen
```

Im Web-UI erscheinen die Sender unter **Radio** (Seite `PageRadioStreams`) bzw. **Playlists**.

Verifiziert: alle 13 Sender werden als Playlist mit `stream_count: 1` gelistet; Ö1 (MP3 192) und FIP (AAC, 189 kbps, 48000 Hz) hat OwnTone/ffmpeg erfolgreich dekodiert.

## Web-UI / API-Zugriff

- **LAN**: `http://<router-ip>:3689` — funktioniert, inklusive Web-UI aus `/usr/share/owntone/htdocs`.
- **Andere Netze (z. B. Tailnet/VPN)**: Owntone 28.5 antwortet mit **403 Forbidden**. Grund ist `trusted_networks` in `/etc/owntone.conf` (Default: `localhost`, `192.168`, `fd`). Für Fernzugriff:

```
trusted_networks = { "localhost", "192.168", "fd", "100." }
```

```sh
/etc/init.d/owntone restart
```

  (`100.` deckt den Tailscale-Bereich `100.64.0.0/10` ab; bewusst weit gefasst — jeder in diesem Netz käme dann ohne Passwort rein. `admin_password` existiert, externe Logins unterstützt 28.5 aber noch nicht, das kam erst mit 28.11.)
- **Log**: `/var/log/owntone.log`

## Verifikation (Referenzgerät)

| Prüfung | Ergebnis |
| :--- | :--- |
| Dienst | `owntone 28.5` läuft als Benutzer `owntone`, Autostart aktiv |
| HomePod-Erkennung | als `type HomePod` und `type: AirPlay 2` gelistet (dank `raop_disable`) |
| Radio-Pipeline | Ö1 (`https://orf-live.ors-shoutcast.at/oe1-q2a`) wird aufgelöst: `type: mp3`, 192 kbps, 48000 Hz, 2 ch |
| AirPlay-Ausgabe | **funktioniert**: Ö1 → OwnTone → AirPlay 2 → HomePod (OS 27), inkl. automatischem Reconnect |
| Nötige Zusatz-Config | `user_agent = "AirPlay/540.31"` (HomePod OS 27 lehnt `owntone/28.5` mit `403` ab), `raop_disable = true`, **kein** `password` (Home-App ohne „Require Password") |
| Fallback `ipv6 = no` | getestet, hilft nicht |

## Bekanntes Problem: HomePod-Ausgabe lässt sich nicht aktivieren

Der HomePod stellt **drei** Hürden. Die Log-Meldung (`/var/log/owntone.log`) zeigt, an welcher es hängt:

| Log-Meldung | Ursache | Lösung |
| :--- | :--- | :--- |
| `Response to GET /info (probe) ... 403 Forbidden` | Zugriffsfreigabe in der Home-App zu restriktiv | Home-App → Home-Einstellungen → **Speaker & TV** → „Anyone on the Same Network" (oder „Everyone") |
| dieselbe `403`, obwohl die Freigabe gesetzt ist | OwnTone sendet `owntone/28.5` als User-Agent — HomePod OS 27 lehnt das ab | `user_agent = "AirPlay/540.31"` in der `general`-Sektion |
| `requires password authentication, but none given in config` | In der Home-App ist „Require Password" aktiv | Entweder `password = "…"` in den `airplay`-Block — oder „Require Password" ausschalten |
| `Pairing step 2 … authentication failure` bzw. `Response to SETUP (session) … 401 Unauthorized` | Passwort-Modus passt nicht zusammen | **Verifiziert funktionierend: „Require Password" aus + kein `password` in der Config** (Transient Pairing) |

> Mit gesetztem Passwort läuft das HAP-Pairing zwar an, der HomePod OS 27 weist die Session danach aber mit `401` zurück und OwnTone verwirft die Schlüssel — daher derzeit ohne Passwort betreiben.

`files/configure-owntone.sh` richtet `user_agent`, den `airplay`-Block und optional das Passwort in einem Schritt ein:

```sh
sh /tmp/configure-owntone.sh Wohnzimmer
```

Retest (Body-Vorlage: `files/api-select-output.json`, auf dem Router z. B. unter `/tmp/`):

```sh
curl -s -X PUT -H 'Content-Type: application/json' \
  -d @/tmp/api-select-output.json \
  http://127.0.0.1:3689/api/outputs/<output-id>
```

Erwartung: `HTTP/1.1 204 No Content` statt `500`. Die Output-ID liefert `GET /api/outputs`.

## Persistenz

Paket und `/etc`-Änderungen liegen im Overlay und überleben „Keep Settings"-Updates; das Paket wird bei Firmware-Updates dennoch entfernt und muss neu installiert werden.
