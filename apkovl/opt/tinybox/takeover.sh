#!/bin/sh

# show what commands are being run
set -x

sleep 1

# Check if the script is up to date
# if ! wget -q -O /tmp/update.sh "http://192.168.21.33:2133/takeover.sh"; then
#   echo "text,Failed Update" | nc -U /run/tinybox-screen.sock 2>/dev/null
#   exit 1
# fi

# calculate hash for the remote script
# remote_script_hash="$(sha256sum /tmp/update.sh | awk '{print $1}')"
# calculate hash for the local script
# local_script_hash="$(sha256sum /opt/tinybox/takeover.sh | awk '{print $1}')"

# compare hashes
# if [ "$remote_script_hash" != "$local_script_hash" ]; then
#  echo "text,Updating..." | nc -U /run/tinybox-screen.sock 2>/dev/null
#  sleep 1
#  mv /tmp/update.sh /opt/tinybox/takeover.sh
#  chmod +x /opt/tinybox/takeover.sh
#  exec /opt/tinybox/takeover.sh "$@"
#  exit 0
# fi

NFS_HOST="192.168.21.33"

# install on /dev/nvme4n1
EXPECTED_OS_DRIVE="/dev/nvme4n1"

# system check
# EXPECTED_GPU_COUNT=6
EXPECTED_GPU_COUNT=2
EXPECTED_GPU_LINK_SPEED="16GT/s"
EXPECTED_GPU_LINK_WIDTH="x16"
# EXPECTED_MEMORY_SIZE_GB=128
EXPECTED_MEMORY_SIZE_GB=64
EXPECTED_CORE_COUNT=32
EXPECTED_DRIVE_COUNT=5
EXPECTED_DRIVE_LINK_SPEED="16GT/s"
EXPECTED_DRIVE_LINK_WIDTH="x4"

echo "atext,System Check.. ,System Check ..,System Check. ." | nc -U /run/tinybox-screen.sock 2>/dev/null
# retrieve detailed hardware information
system_info="$(lshw -json)"

# first check the gpus
gpu_busids="$(echo "$system_info" | jq -r '.. | objects | select(.class == "display") | select(.vendor | . and contains("ASPEED") | not) | .businfo | .[4:]')"
gpu_count=$(echo "$gpu_busids" | wc -l)
echo "text,Found $gpu_count GPUs" | nc -U /run/tinybox-screen.sock 2>/dev/null
if [ "$gpu_count" -ne "$EXPECTED_GPU_COUNT" ]; then
  echo "text,GPU Count should be ${EXPECTED_GPU_COUNT},is $gpu_count" | nc -U /run/tinybox-screen.sock 2>/dev/null
  exit 1
fi
i=0
for busid in $gpu_busids; do
  echo "text,Checking GPU $i,$busid" | nc -U /run/tinybox-screen.sock

  link_speed=$(lspci -vv -s "$busid" | grep "LnkCap:" | grep -oP 'Speed \d+GT/s' | grep -oP '\d+GT/s')
  if [ "$link_speed" != "$EXPECTED_GPU_LINK_SPEED" ]; then
    echo "text,$busid - GPU $i,not at $EXPECTED_GPU_LINK_SPEED,at $link_speed" | nc -U /run/tinybox-screen.sock 2>/dev/null
    exit 1
  fi
  link_width=$(lspci -vv -s "$busid" | grep "LnkCap:" | grep -oP 'Width x\d+' | grep -oP 'x\d+')
  if [ "$link_width" != "$EXPECTED_GPU_LINK_WIDTH" ]; then
    echo "text,$busid - GPU $i,not at $EXPECTED_GPU_LINK_WIDTH,at $link_width" | nc -U /run/tinybox-screen.sock 2>/dev/null
    exit 1
  fi

  # Ensure resizable BAR (Base Address Register) is enabled for the GPU
  # It is a PCIe feature allowing the CPU to access the entire GPU frame buffer (VRAM) at once to improve performance
  if ! lspci -vv -s "$busid" | grep -q "Resizable BAR"; then
    echo "text,$busid - GPU $i,Resizable BAR not enabled" | nc -U /run/tinybox-screen.sock 2>/dev/null
    exit 1
  fi

  i=$((i + 1))
done

# check the ram
memory_size=$(echo "$system_info" | jq -r '.. | objects | select(.id == "memory") | .size')
memory_size_gb=$(echo "$memory_size" | awk '{print int($1/1024/1024/1024)}')
echo "text,Found $memory_size_gb GB" | nc -U /run/tinybox-screen.sock 2>/dev/null
if [ "$memory_size_gb" -ne "$EXPECTED_MEMORY_SIZE_GB" ]; then
  echo "text,Memory should be ${EXPECTED_MEMORY_SIZE_GB} GB,is $memory_size_gb GB" | nc -U /run/tinybox-screen.sock 2>/dev/null
  exit 1
fi

# check the cpu
core_count=$(echo "$system_info" | jq -r '.. | objects | select(.class == "processor") | .configuration.enabledcores')
echo "text,Found $core_count Cores" | nc -U /run/tinybox-screen.sock
if [ "$core_count" -ne "$EXPECTED_CORE_COUNT" ]; then
  echo "text,Core Count should be ${EXPECTED_CORE_COUNT},is $core_count" | nc -U /run/tinybox-screen.sock 2>/dev/null
  exit 1
fi

# check the nvme drives
drive_busids=$(echo "$system_info" | jq -r '.. | objects | select(.class == "disk") | select(.description | . and contains("NVMe")) | select(.businfo | . and contains("nvme")) | .businfo')
drive_count=$(echo "$drive_busids" | wc -l)
echo "text,Found $drive_count Drives" | nc -U /run/tinybox-screen.sock
if [ "$drive_count" -ne "$EXPECTED_DRIVE_COUNT" ]; then
  echo "text,Drive Count should be ${EXPECTED_DRIVE_COUNT},is $drive_count" | nc -U /run/tinybox-screen.sock 2>/dev/null
  exit 1
fi
i=0
for busid in $drive_busids; do
  # grab the pcie busid
  nvmeid="$(echo "$busid" | grep -oP '@\d' | grep -oP '\d')"
  busid="$(cat /sys/class/nvme/nvme"$nvmeid"/address)"
  echo "text,Checking Drive $i,$busid" | nc -U /run/tinybox-screen.sock 2>/dev/null

  link_speed=$(lspci -vv -s "$busid" | grep "LnkCap:" | grep -oP 'Speed \d+GT/s' | grep -oP '\d+GT/s')
  if [ "$link_speed" != "$EXPECTED_DRIVE_LINK_SPEED" ]; then
    echo "text,$busid - Drive $i,not at $EXPECTED_DRIVE_LINK_SPEED,at $link_speed" | nc -U /run/tinybox-screen.sock 2>/dev/null
    exit 1
  fi
  link_width=$(lspci -vv -s "$busid" | grep "LnkCap:" | grep -oP 'Width x\d+' | grep -oP 'x\d+')
  if [ "$link_width" != "$EXPECTED_DRIVE_LINK_WIDTH" ]; then
    echo "text,$busid - Drive $i,not at $EXPECTED_DRIVE_LINK_WIDTH,at $link_width" | nc -U /run/tinybox-screen.sock 2>/dev/null
    exit 1
  fi

  i=$((i + 1))
done

echo "text,System Check Complete" | nc -U /run/tinybox-screen.sock 2>/dev/null
sleep 1

# find first /dev/sd{a-z} that is not mounted
# drive=""
drive="$EXPECTED_OS_DRIVE"

if [ -z "$drive" ]; then
  echo "text,No Drive Found" | nc -U /run/tinybox-screen.sock 2>/dev/null
  exit 1
fi

echo "text,Using Drive,$drive" | nc -U /run/tinybox-screen.sock 2>/dev/null
sleep 1

# mount the nfs share that stores the image
apk update
apk add nfs-utils
mkdir -p /tmp/tmp
mount -t nfs "$NFS_HOST:/home/fastctl/share /tmp/tmp"

# determine which image we are downloading and flashing
is_nvidia=$(echo "$system_info" | jq -r '.. | objects | select(.class == "display") | select(.vendor | . and contains("ASPEED") | not) | .vendor' | head -n1 | grep -i "nvidia")
if [ -n "$is_nvidia" ]; then
  echo "text,Downloading green Image" | nc -U /run/tinybox-screen.sock 2>/dev/null
else
  echo "text,Downloading red Image" | nc -U /run/tinybox-screen.sock 2>/dev/null
fi
sleep 1

echo "text,Flashing Image" | nc -U /run/tinybox-screen.sock 2>/dev/null

# get file size
file_size=$(stat -c %s /tmp/tmp/tinyos.img)

# Run watch command in the background. The watch command executes pkill -USR1 dd every second.
# This sends a USR1 signal to the dd command, which causes dd to print its I/O progress to
# standard error.
watch -t -n1 pkill -USR1 dd >/dev/null &

# write the image to the drive
# Use dd to copy the image file (/tmp/tmp/tinyos.img) to the drive ($drive) with a block size of 16M.
# The oflag=direct ensures that the write bypasses any caching mechanisms.
# The 2>&1 redirects standard error to standard output so that progress messages can be
# read by the while read -r line loop.
dd if=/tmp/tmp/tinyos.img of="$drive" bs=16M oflag=direct 2>&1 | while read -r line; do
  case $line in
  *"bytes"*)
    # extract the written bytes from the line
    written=$(echo "$line" | grep -oP '\d+' | head -n1)
    # calculate the percentage of the written bytes
    percentage=$(awk "BEGIN {print int(($written/$file_size)*100)}")
    # extract the speed
    speed=$(echo "$line" | grep -oP '(\d+.\d+MB/s)|(\d+ MB/s)|(\d+B/s)')
    echo "text,Flashing Image,$percentage% - $speed" | nc -U /run/tinybox-screen.sock 2>/dev/null
    ;;
  esac
done
pkill watch

sleep 30

# fix the backup gpt header
sgdisk -e "$drive"

sleep 10

# delete previous tinyos uefi boot entries no bash
# get the tinyos uefi boot entries
entries="$(efibootmgr | grep -i "tinyos" | grep -oP 'Boot\d+' | grep -oP '\d+')"
# delete each tinyos uefi boot entry
for entry in $entries; do
  efibootmgr -b "$entry" -B
done

sleep 10

# tell uefi to boot from the internal drive
# create a new uefi boot entry
efibootmgr --create --disk "$drive" --part 1 --label "tinyos" --loader '\EFI\BOOT\BOOTX64.EFI'

sleep 10

# retrieve the boot entry number
bootnum="$(efibootmgr | grep -i "tinyos" | grep -oP 'Boot\d+' | grep -oP '\d+' | head -n1)"
# set the boot entry as the next boot target
efibootmgr -n "$bootnum"

echo "text,Flashing Complete,Rebooting" | nc -U /run/tinybox-screen.sock 2>/dev/null
sleep 30

# reboot
