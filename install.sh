#!/usr/bin/env bash
set -eu
set -a

DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPT_DIR=$DIR/scripts
CONFIG_DIR=$DIR/configs
DOTFILE_DIR=$CONFIG_DIR/dotfiles
ETC_DIR=$CONFIG_DIR/etc
source $DIR/install.conf
echo "Execution Directory Is: $DIR"

set +a

( sh $SCRIPT_DIR/preinstall.sh )|& tee $DIR/preinstall.log
cp -r $DIR /mnt$DIR
# enable nopasswd for sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /mnt/etc/sudoers.d/99_wheel_nopasswd
( arch-chroot /mnt $SCRIPT_DIR/setup.sh )|& tee $DIR/setup.log
( arch-chroot /mnt $SCRIPT_DIR/postinstall.sh )|& tee $DIR/postinstall.log
# disable nopasswd for sudo
rm /mnt/etc/sudoers.d/99_wheel_nopasswd
# rm -r /mnt$DIR
print_section "Arch Linux Should Be Installed"