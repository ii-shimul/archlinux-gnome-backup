#!/usr/bin/env bash
set -Eeuo pipefail
dest=${1:-"/run/media/bax/Varieties/Linux Settings Backup/"}
mkdir -p "$dest"

echo "[*] Writing to: $dest"

# 1) dconf (all + focused subsets)
if command -v dconf >/dev/null 2>&1; then
  echo "[*] Dumping dconf…"
  dconf dump / > "$dest/dconf-all.ini"
  dconf dump /org/gnome/ > "$dest/dconf-gnome.ini" || true
  dconf dump /org/gnome/shell/extensions/ > "$dest/dconf-extensions.ini" || true
fi

# 2) GNOME extensions (lists + user-installed contents)
if command -v gnome-extensions >/dev/null 2>&1; then
  echo "[*] Listing extensions…"
  gnome-extensions list > "$dest/gnome-extensions-all.txt" || true
  gnome-extensions list --enabled > "$dest/gnome-extensions-enabled.txt" || true
fi
echo "[*] Archiving user extensions…"
tar -C "$HOME/.local/share" -czf "$dest/gnome-user-extensions.tgz" gnome-shell/extensions 2>/dev/null || true

# 3) Themes, icons, fonts
echo "[*] Archiving themes/icons/fonts…"
tar -C "$HOME" -czf "$dest/themes-icons-fonts.tgz" \
  .themes .icons .local/share/icons .local/share/themes .local/share/fonts 2>/dev/null || true

# 4) Desktop/GTK, MIME, autostart, env.d, Nautilus, gnome-shell data, IBus, PipeWire/WirePlumber
echo "[*] Archiving desktop config…"
tar -C "$HOME" -czf "$dest/desktop-config.tgz" \
  .config/gtk-3.0 .config/gtk-4.0 .config/mimeapps.list .config/user-dirs.dirs .config/user-dirs.locale \
  .config/nautilus .local/share/nautilus .local/share/applications \
  .config/autostart .config/environment.d \
  .local/share/gnome-shell .local/share/ibus .config/ibus \
  .config/pipewire .config/wireplumber \
  .config/monitors.xml 2>/dev/null || true

# 5) Pacman package lists
if command -v pacman >/dev/null 2>&1; then
  echo "[*] Capturing pacman package lists…"
  pacman -Qqe  > "$dest/pacman-explicit.txt"
  pacman -Qqen > "$dest/pacman-explicit-native.txt" || true
  pacman -Qqm  > "$dest/pacman-foreign-AUR.txt" || true
fi

# 6) Flatpak (if used)
if command -v flatpak >/dev/null 2>&1; then
  echo "[*] Capturing Flatpak info…"
  flatpak remotes --columns=name,url > "$dest/flatpak-remotes.txt"
  flatpak list --app --columns=application > "$dest/flatpak-apps.txt"
fi

# 7) User systemd (enabled services/timers)
if command -v systemctl >/dev/null 2>&1; then
  echo "[*] Recording enabled user services/timers…"
  systemctl --user list-unit-files --type=service --state=enabled > "$dest/systemd-user-services.txt" || true
  systemctl --user list-unit-files --type=timer   --state=enabled > "$dest/systemd-user-timers.txt"   || true
fi

# 8) Optional system configs + secrets (sudo)
if command -v sudo >/dev/null 2>&1; then
  echo "[*] Archiving important /etc items (sudo)…"
  sudo bash -c "
    tar -czf '$dest/etc-essentials.tgz' \
      /etc/pacman.conf /etc/pacman.d/mirrorlist /etc/pacman.d/hooks \
      /etc/locale.conf /etc/vconsole.conf /etc/environment \
      /etc/NetworkManager/system-connections /etc/cups /etc/fonts \
      2>/dev/null || true
    tar -czf '$dest/var-bluetooth.tgz' /var/lib/bluetooth 2>/dev/null || true
  "
fi

# 9) Common shell dotfiles
echo "[*] Archiving shell dotfiles…"
tar -C "$HOME" -czf "$dest/shell-dotfiles.tgz" \
  .bashrc .bash_profile .zshrc .profile .xprofile .pam_environment 2>/dev/null || true

# 10) Restore cheat‑sheet
cat > "$dest/README-RESTORE.txt" <<'EOF'
== RESTORE ORDER (summary) ==
1) Fresh Arch base, network online.
2) (Optional) Restore pacman config and mirrorlist:
   sudo tar -xzf etc-essentials.tgz -C /
3) Reinstall packages:
   sudo pacman -Syu --needed - < pacman-explicit-native.txt
   # For AUR:
   #   yay  -S --needed - < pacman-foreign-AUR.txt
   #   paru -S --needed - < pacman-foreign-AUR.txt
4) Flatpak:
   sudo pacman -S --needed flatpak
   while read -r name url; do [ -n "$name" ] && [ "$name" != "Name" ] && flatpak remote-add --if-not-exists "$name" "$url"; done < flatpak-remotes.txt
   xargs -r -a flatpak-apps.txt flatpak install -y --or-update
5) Themes/icons/fonts:
   tar -xzf themes-icons-fonts.tgz -C ~
   fc-cache -rv
6) Extensions:
   tar -xzf gnome-user-extensions.tgz -C ~/.local/share
   xargs -a gnome-extensions-enabled.txt -r -I{} gnome-extensions enable "{}"
7) Desktop/GTK & app integrations:
   tar -xzf desktop-config.tgz -C ~
8) Load GNOME settings (IMPORTANT: do this from a TTY with the GNOME session closed):
   dconf load / < dconf-all.ini
   # or narrower:
   # dconf load /org/gnome/ < dconf-gnome.ini
9) Secrets (careful):
   # GNOME Keyring (user)
   tar -xzf gnome-keyring.tgz -C ~
   chmod 700 ~/.local/share/keyrings
   # NetworkManager (system)
   sudo tar -xzf networkmanager-profiles.tgz -C /
   sudo chown -R root:root /etc/NetworkManager/system-connections
   sudo chmod 600 /etc/NetworkManager/system-connections/*
   sudo systemctl restart NetworkManager
10) User services:
    awk 'NR>1 && $1 ~ /\.service$/ {print $1}' systemd-user-services.txt | xargs -r systemctl --user enable --now
    awk 'NR>1 && $1 ~ /\.timer$/   {print $1}' systemd-user-timers.txt   | xargs -r systemctl --user enable --now

Log back into GNOME, verify extensions/favorites/shortcuts. Reboot if anything looks off.
EOF

echo "[✓] Backup complete: $dest"
echo "Consider encrypting the folder/tarballs (e.g., with age or gpg) before syncing off‑machine."

