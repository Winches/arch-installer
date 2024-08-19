#!/usr/bin/env bash
source $DIR/install.conf

efi_boot_mode(){
    [[ -d /sys/firmware/efi/efivars ]] && return 0
    return 1
}

umount_device () {
    SWP=$(swapon --show | awk 'NR>1 {print $1}')
    if [ -n "$SWP" ]; then
        swapoff $SWP
    fi
    while [[ $(findmnt /mnt) != "" ]]
    do 
        umount -l /mnt;
    done
    # umount -A --recursive /mnt &>/dev/null
    echo "umount devices"
}

print_section "Base Installtion"
# ensure boot mode
if efi_boot_mode; then BOOT_MODE="UEFI"; else BOOT_MODE="BIOS"; fi
print_info "Boot In ${BOOT_MODE} Mode"

# load keys
if [ -n "$KEYMAP" ]; then
    loadkeys $KEYMAP
    print_info "Load $KEYMAP keymap"
fi

# connect wifi
if [ -n "$WIFI_ESSID" ]; then
    iwctl --passphrase "$WIFI_KEY" station $WIFI_INTERFACE connect "$WIFI_ESSID"
    print_info "Connect to WiFi $WIFI_INTERFACE"
fi

# test internet
print_info "Testing Network . . ."
$(ping -c 3 archlinux.org &>/dev/null) || (print_error "Not Connected to Network!!!" && exit 1)
print_info "Internet Is Available"

# ensure time
timedatectl set-ntp true
print_info "Time Status Is . . ."
timedatectl status
sleep 3

print_info "Install Base System"
# setup filesystems(UEFI only)
# ask user just in case
if confirm "The '${DISK_DEVICE}' will be wiped"; then
    # partition disk
    print_info "Format Partitions"
    umount_device && sleep 3

    sgdisk -Z "$DISK_DEVICE"
    sgdisk -n 1::+"$EFI_SIZE" -t 1:ef00 -c 1:EFI "$DISK_DEVICE"
    sgdisk -n 2::+"$SWAP_SIZE" -t 2:8200 -c 2:SWAP "$DISK_DEVICE"
    sgdisk -n 3::+"$ROOR_SIZE" -t 3:8300 -c 3:HOME "$DISK_DEVICE" # use free sapce if ROOR_SIZE is empty
    mkfs.fat -F 32 $EFI_DEVICE
    mkfs.ext4 $ROOT_DEVICE
    mkswap $SWAP_DEVICE

    # mount filesystems
    print_info "Mount Filesystems"
    mount $ROOT_DEVICE /mnt
    mount  --mkdir -o fmask=0137,dmask=0027 $EFI_DEVICE /mnt/$ESP # configure permission with '-o' to avoid security issue
    swapon $SWAP_DEVICE
else
    print_warning "Do nothing with '${DISK_DEVICE}'"
fi
print_info "Partitions Is . . ."
lsblk

# mirrorlist
print_info "Update Mirrorlist . . ."
ISO=$(curl -4 ifconfig.co/country-iso) # optional: ipinfo.io/country
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
reflector --age 24 --country $ISO --latest 25 --sort rate --protocol https --save /etc/pacman.d/mirrorlist

# install base
print_info "Install Base"
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacman -Syy --noconfirm
pacstrap -K /mnt --noconfirm $(sed '/^\s*#/d; /^\s*$/d' $CONFIG_DIR/base.list)
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

# fstab
genfstab -U /mnt >> /mnt/etc/fstab
# sed -i "s/^fmask=0022,dmask=0022/fmask=0137,dmask=0027/" > /mnt/etc/fstab