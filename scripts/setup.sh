#!/usr/bin/env bash
source $DIR/install.conf

print_section "System Configuration"

# time
print_info "Setup Time"
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc # create /etc/adjtime
# instead of 'timedatectl set-ntp true'(it must be executed after reboot)
systemctl enable systemd-timesyncd.service

# localization
print_info "Setup Localization"
sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen
cat > /etc/locale.conf << EOF
LANG=$LOCALE
LC_NUMERIC=$LOCALE
LC_TIME=$LOCALE
LC_MONETARY=$LOCALE
LC_PAPER=$LOCALE
LC_NAME=$LOCALE
LC_ADDRESS=$LOCALE
LC_TELEPHONE=$LOCALE
LC_MEASUREMENT=$LOCALE
LC_IDENTIFICATION=$LOCALE
EOF
echo "KEYMAP=$KEYMAP" >> /etc/vconsole.conf

# network
print_info "Setup Network"
echo "$HOSTNAME" >> /etc/hostname
echo "Setup hostname"
cat > /etc/hosts <<HOSTS
127.0.0.1      localhost
::1            localhost
127.0.1.1      $HOSTNAME.localdomain     $HOSTNAME
HOSTS
echo "Setup hosts"

# user
print_info "Setup User"
echo "root:$ROOT_PASSWORD" | chpasswd
echo "Set password for root"
cat > /etc/sudoers.d/00_wheel << EOF
%wheel ALL=(ALL:ALL) ALL
EOF
if ! user_exists "$USER_NAME" && [ -n "$USER_NAME" ]; then
    useradd -m -G wheel $USER_NAME
    echo "The user '$USER_NAME' is added to suoders"
    echo -n "user groups: "
    groups $USER_NAME
    # set user password
    echo "$USER_NAME:$PASSWORD" | chpasswd
    echo "Set password for $USER_NAME"
else
    print_warning "'$USER_NAME' already exists"
fi

# pacman
print_info "Setup Pacman"
cp /etc/pacman.conf /etc/pacman.conf.bak
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
echo "Pacman is configured"

# microcode
print_info "Setup Microcode"
PROC_TYPE=$(lscpu)
if grep -E "GenuineIntel" <<< ${PROC_TYPE}; then
    print_info "Installing Intel microcode"
    pacman -Sq --noconfirm --needed intel-ucode
    MICROCODE=intel-ucode.img
elif grep -E "AuthenticAMD" <<< ${PROC_TYPE}; then
    print_info "Installing AMD microcode"
    pacman -Sq --noconfirm --needed amd-ucode
    MICROCODE=amd-ucode.img
fi

# bootloader
print_info "Setup Bootloader"
boot_entry () {
    kernel=$1
    init_ucode=""
    if [ -n "$2" ]; then init_ucode="initrd  /$2"; fi
    linux_root=$3
    kernel_params=$4

cat > $ESP/loader/entries/arch-$kernel.conf << EOF
title   Arch Linux ($kernel)
linux   /vmlinuz-linux
$init_ucode
initrd  /initramfs-$kernel.img
options root=UUID=${ROOT_UUID} rw $kernel_params
EOF

cat > $ESP/loader/entries/arch-$kernel-fallback.conf << EOF
title   Arch Linux ($kernel, fallback initramfs)
linux   /vmlinuz-linux
$init_ucode
initrd  /initramfs-$kernel-fallback.img
options root=UUID=${ROOT_UUID} rw $kernel_params
EOF
}

echo "Installing systemd-boot to $ESP"
KERNEL="linux"
KERNEL_PARAMS="quiet"
ROOT_UUID=$(blkid -s UUID -o value $ROOT_DEVICE)

bootctl install --esp-path=$ESP
if [ $(bootctl is-installed) == "yes" ]; then
cat > $ESP/loader/loader.conf << EOF
default  arch-$KERNEL.conf
timeout  4
console-mode max
editor   no
EOF
    boot_entry $KERNEL $MICROCODE $ROOT_UUID $KERNEL_PARAMS
    print_info "Bootloader has been installed"
else
    print_error "Bootloader is not installed"
    bootctl status
fi