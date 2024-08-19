#!/usr/bin/env bash
source $DIR/install.conf

USER_HOME=/home/$USER_NAME

# enable service if pacakge exists
try_enable_service () {
    package="$1"
    service="$2"
    if package_exists $package; then
        systemctl enable $service
        echo "Enable Service/Timer $service"
    fi
}

# check device is SSD or not
is_ssd() {
    device="$(basename $1)"

    if [ ! -b "$1" ]; then
        echo "$1 not exists"
        return 1
    fi

    if [ "$(cat /sys/block/$device/queue/rotational)" -eq 0 ]; then
        echo "$1 is SSD"
        return 0
    else
        echo "$1 is not SSD"
        return 1
    fi
}

# install aur helper
install_aur () {
    aur=$1
    usr=$2
    pacman -S --noconfirm --needed base-devel git
    su -c "cd ~ && git clone https://aur.archlinux.org/${aur}.git" $usr
    su -c "cd ~/${aur} && makepkg -sifc --noconfirm" $usr
    su -c "rm -rf ~/${aur}" $usr
}

print_section "Post Installation"

# install essential packages
install_from_list essential

# install desktop environment
if confirm "Desktop-Environment will be installed"; then
    install_from_list desktop
fi

# install extra packages
if confirm "Extra packages will be installed"; then
    install_from_list extra
fi

# install helper
print_info "Install AUR Helper"
if [ -n $AUR ] && user_exists "$USER_NAME"; then
    install_aur $AUR $USER_NAME
    if which yay &> /dev/null; then
        print_info "AUR Helper is installed"
    else
        print_error "AUR Helper is not installed"
    fi
else
    print_error "AUR Helper cannot be installed"
fi

# install zsh framework
if [ -n $ZSH_FRAMEWORK ] && package_exists zsh; then
    print_info "Installing Zsh Framework"
    pacman -S --noconfirm --needed curl
    case $ZSH_FRAMEWORK in
        "oh-my-zsh")
            echo "Installing $ZSH_FRAMEWORK"
            URL="https://install.ohmyz.sh/"
            su -c "sh -c '$(curl -fsSL $URL) --unattended'" $USER_NAME
            ;;
        *)
            print_error "Zsh Framework: $ZSH_FRAMEWORK is not supported"
            ;;
    esac
fi

# configure shell
print_info "Setup Shell"
LOGIN_SHELL=${LOGIN_SHELL:-"bash"}
SHELL_PATH=$(which $LOGIN_SHELL)
echo "Set default shell with $SHELL_PATH"
chsh -s $SHELL_PATH
chsh -s $SHELL_PATH $USER_NAME

# configure boot splash
if package_exists plymouth; then
    print_info "Setup Boot Splash"
    sed -i '/^options/s/$/ splash/' /boot/loader/entries/arch-linux.conf
    sed -i '/^options/s/$/ splash/' /boot/loader/entries/arch-linux-fallback.conf
    sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf
    plymouth-set-default-theme -R bgrt
fi

# enable service
print_info "Setup Service"
try_enable_service pacman-contrib paccache.timer
try_enable_service networkmanager NetworkManager
try_enable_service reflector reflector.timer
try_enable_service ufw ufw
try_enable_service gdm gdm
try_enable_service bluez Bluetooth
try_enable_service avahi avahi-daemon
if is_ssd $DISK_DEVICE ; then systemctl enable fstrim.timer; fi

print_info "Copy Configuration Files"
# copy system-wide settings
if [ -d $ETC_DIR ]; then
    chmod 644 $ETC_DIR/profile.d/*
    cp -rv $ETC_DIR/profile.d/. /etc/profile.d
    print_info "The etc has been copied"
else
    print_warning "No etc found,skipping file copy"
fi