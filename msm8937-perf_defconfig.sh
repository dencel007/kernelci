#!/bin/bash

# Template from https://github.com/bitrvmpd/msm-3.18/blob/rel/msm-3.18-oreo/build.sh
# Thanks to Eduardo Noyer (https://github.com/bitrvmpd)

clear
echo "#########################################"
echo "##### msm8937-perf_defconfig Kernel - Build Script #####"
echo "#########################################"

# Make statement declaration
# ==========================
# If compilation uses menuconfig, make operation will use .config 
# instead of santoni_defconfig directly.
MAKE_STATEMENT=make

# ENV configuration
# =================
export PHANTOM_WORKING_DIR=$(dirname "$(pwd)")

export KBUILD_BUILD_USER="Dencel"
export KBUILD_BUILD_HOST="Zeus"
export DEVICE="msm8937-perf_defconfig";

export ZIP_DIR="${KERNEL_DIR}/AnyKernel2"
export ZIP_NAME="${KERNEL_NAME}-${DEVICE}-$(date +%Y%m%d-%H%M).zip";
export FINAL_ZIP="${ZIP_DIR}/${ZIP_NAME}"

export IMAGE="${KERNEL_DIR}/arch/arm64/boot/Image.gz-dtb";


$MAKE_STATEMENT mrproper;
$MAKE_STATEMENT clean;
rm -rf $IMAGE

# CCACHE configuration
# ====================
# If you want you can install ccache to speedup recompilation time.
# In ubuntu just run "sudo apt-get install ccache".
# By default CCACHE will use 2G, change the value of CCACHE_MAX_SIZE
# to meet your needs.
if [ -x "$(command -v ccache)" ]
then
  # If you want to clean the ccache
  # run this script with -clear-ccache
  if [[ "$*" == *"-clear-ccache"* ]]
  then
    echo -e "\n\033[0;31m> Cleaning $PHANTOM_WORKING_DIR/.ccache contents\033[0;0m" 
    rm -rf "$PHANTOM_WORKING_DIR/.ccache"
  fi
  # If you want to build *without* using ccache
  # run this script with -no-ccache flag
  if [[ "$*" != *"-no-ccache"* ]] 
  then
    export USE_CCACHE=1
    export CCACHE_DIR="$PHANTOM_WORKING_DIR/.ccache"
    export CCACHE_MAX_SIZE=6G
    echo -e "\n> $(ccache -M $CCACHE_MAX_SIZE)"
    echo -e "\n\033[0;32m> Using ccache, to disable it run this script with -no-ccache\033[0;0m\n"
  else
    echo -e "\n\033[0;31m> NOT Using ccache, to enable it run this script without -no-ccache\033[0;0m\n"
  fi
else
  echo -e "\n\033[0;33m> [Optional] ccache not installed. You can install it (in ubuntu) using 'sudo apt-get install ccache'\033[0;0m\n"
fi

# Want to use a different toolchain? (Linaro, UberTC, etc)
# ==================================
# point CROSS_COMPILE to the folder of the desired toolchain
# don't forget to specify the prefix. Mine is: aarch64-linux-android-
CROSS_COMPILE=$PHANTOM_WORKING_DIR/aarch64-linux-android-4.9/bin/aarch64-linux-android-

# Are we using ccache?
if [ -n "$USE_CCACHE" ] 
then
  CROSS_COMPILE="ccache $CROSS_COMPILE"  
fi

# Build starts here
# =================
echo -e "> Opening .config file...\n"

ARCH=arm64 SUBARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE make msm8937-perf_defconfig -j8;
echo -e "> Starting kernel compilation using .config file...\n"

start=$SECONDS

# Want custom kernel flags?
# =========================
# KBUILD_PHANTOM_CFLAGS: Here you can set custom compilation 
# flags to turn off unwanted warnings, or even set a 
# different optimization level. 
# To see how it works, check the Makefile ... file, 
# line 625 to 628, located in the root dir of this kernel.
KBUILD_PHANTOM_CFLAGS="-Wno-misleading-indentation -Wno-bool-compare -mtune=cortex-a53 -march=armv8-a+crc+simd+crypto -mcpu=cortex-a53 -O2" 
KBUILD_PHANTOM_CFLAGS=$KBUILD_PHANTOM_CFLAGS ARCH=arm64 SUBARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE $MAKE_STATEMENT -j8

if [[ ! -f "${IMAGE}" ]]; then
    echo -e "\n\033[0;31m> Image.gz-dtb not FOUND. Build failed \033[0;0m\n";
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="Image.gz-dtb not FOUND. Build failed !. $KERNEL_NAME CI Build stopped unexpectedly ! " -d chat_id=$CHAT_ID
    success=false;
    exit 1;
else
    echo -e "\n\033[0;32m> Image.gz-dtb FOUND. Build Successful \033[0;0m\n" ;
    success=true;
fi

# Get current kernel version
PHANTOM_VERSION=$(head -n3 Makefile | sed -E 's/.*(^\w+\s[=]\s)//g' | xargs | sed -E 's/(\s)/./g')
echo -e "\n\n\033[0;34m> Packing PHANTOM Kernel v$PHANTOM_VERSION $ZIP_NAME\n\033[0;0m\n" 

end=$SECONDS
duration=$(( end - start ))
printf "\n\033[0;31m> $KERNEL_NAME CI Build Completed in %dh:%dm:%ds\033[0;0m\n \n" $(($duration/3600)) $(($duration%3600/60)) $(($duration%60)) 

echo -e "\n\033[0;34m> ================== Now, Let's zip it ! ===================\033[0;0m\n \n"

# Tranfer.sh Function
# ==================
function transfer() {
  zip_name="$(echo $1 | awk -F '/' '{print $NF}')";
  url="$(curl -# -T $1 https://transfer.sh)";
  printf '\n';
  echo -e "\n\033[0;32m> Download ${zip_name} at ${url} \033[0;0m\n" ;
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="$url" -d chat_id=$CHAT_ID
}

cd $KERNEL_DIR

cp $KERNEL_DIR/arch/arm64/boot/Image.gz-dtb $KERNEL_DIR/AnyKernel2
cd $KERNEL_DIR/AnyKernel2/
rm -rf zImage 
mv Image.gz-dtb zImage
rm -rf *.zip
zip -r9 ${FINAL_ZIP} *;
cd -;

if [ -f "$FINAL_ZIP" ];
then
echo -e "\n\033[0;32m> $ZIP_NAME zip can be found at $FINAL_ZIP \033[0;0m\n" ;
if [[ ${success} == true ]]; 
then
    echo -e "\n\033[0;34m> Uploading ${ZIP_NAME} to https://transfer.sh/ \033[0;0m\n" ;
    transfer "${FINAL_ZIP}";

# Emojis for Output Beautification
# ====================
egear="⚙️"
ebeginner="🔰"
eclock="🕐"
ecommit="🗒"
ebook="📕"

message="$egear $KERNEL_NAME CI Build Successful "
header="$ebeginner BUILD DETAILS : "
branch="$ebook Branch : $BRANCH_NAME"
time="$eclock Time Taken : $(($duration%3600/60))m:$(($duration%60))s"
commit="$ecommit Last Commit :  
$(git log --pretty=format:'%h : %s' -5)"
curl -F chat_id="-1001124689793" -F document=@"${ZIP_DIR}/$ZIP_NAME" -F caption="$message 

$header
$branch 
$time
$commit" https://api.telegram.org/bot$BOT_API_KEY/sendDocument
curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="CAADBQADuQADLG6EE9HnR-_L0F2YAg"  -d chat_id=$CHAT_ID

rm -rf ${ZIP_DIR}/${ZIP_NAME}

fi
else
echo -e "\n\033[0;31m> Zip Creation Failed \033[0;0m\n";
fi

echo -e "\n\n\033[0;32m> ======= Everything went fine =======\033[0;0m\n"