# Arch Installer
A simple script for installing the basic arch linux and setting up generic configurations.Mostly for my personal use,bu you can modify it for installing your own arch.

## Usage
1. Boot the arch live environment.
2. Set up network.
3. `git clone repo_url`.
4. Modify `./arch-installer/install.conf`.
5. Copy your files to `/configs/etc`.
6. `sh ./arch-installer/install.sh`.

## Task
1. Base Installtion

    1. Check boot mode.
    2. Load keymap for live environment.
    3. Connect to WiFi if it is configured.
    4. Test network.
    5. Set up Time for live environment.
    6. Format partition if confirmed.
    7. Update mirrorlist
    8. Install base system from `base.list` .
    9. Generate `fstab` .

2. Configure System

    1. Set up time (timezone,network time).
    2. Set up localization.
    3. Set up network (hostname,hosts).
    4. Set up root password and add user if it is configured.
    5. Set up pacman.
    6. Install microcode for processor.
    7. Set up bootloader with systemd-boot.
    
3. Post Installation

    1. Install essential packages from `essential.list` .
    2. Install desktop environment from `desktop.list` .
    3. Install desktop environment from `extra.list` .
    4. Install AUR helper if it is configured.
    5. Install zsh framwork.
    6. Set up default shell.
    7. Set up boot splash screen.
    8. Enable essential services.
    9. Copy `./configs/etc` to `/etc` .