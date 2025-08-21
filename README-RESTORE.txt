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
