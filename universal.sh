#!/bin/bash

# Template from https://github.com/bitrvmpd/msm-3.18/blob/rel/msm-3.18-oreo/build.sh
# Thanks to Eduardo Noyer (https://github.com/bitrvmpd)

# Notes
# =====
# Before building, you should give some export variables such as following ones in build
# 1. ARCH=arm64
# 2. export KERNEL_NAME=Phantom-AOSP-P
# 3. export DIV_NAME=lineage-16.0
# 4. export CHANNEL_ID=-123456789 (channel_id)
# 5. export CHANNEL_NAME=@telegram_channel_name (@channel_name)
# 6. export TCDIR=aarch64-linux-android/bin/aarch64-linux-android-        (GCC 4.9 for example)
# 7. export CDIR=~/linux-x86-master-clang                               (Google Clang 4679922 for example)
# 8. export DEFCONFIG=device_defconfig
#10. export TC_ID=clang

# See ci_script.txt for example server-side setup

clear
echo "#########################################"
echo "####### CI Kernel - Build Script ########"
echo "#########################################"

# Make statement declaration
# ==========================
# If compilation uses menuconfig, make operation will use .config 
# instead of device_defconfig directly.
MAKE_STATEMENT=make

# ENV configuration
# =================
export KERNEL_WORKING_DIR=$(dirname "$(pwd)")

export KBUILD_BUILD_USER="Dencel"
export KBUILD_BUILD_HOST="Zeus"
export DEVICE="HM4X";
export ID_KEY="BRANCH_NAME=clang/"

printenv | sed 's/=\(.*\)/="\1"/' > env.txt
if [[ 'grep "$ID_KEY" env.txt' ]]; then
  export TC_ID=clang
  echo -e "\n\033[0;31m> Identified as a CLANG Branch \033[0;0m\n\n"
else
  echo -e "\n\033[0;31m> Identified as a Normal Branch \033[0;0m\n\n"
fi

if [[ $TC_ID != clang ]]; then
  CROSS_COMPILE=$KERNEL_WORKING_DIR/$TCDIR
fi

export ZIP_DIR="${SEMAPHORE_PROJECT_DIR}/AnyKernel2"
export ZIP_NAME="${KERNEL_NAME}-${DEVICE}-$(date +%Y%m%d-%H%M).zip";
export FINAL_ZIP="${ZIP_DIR}/${ZIP_NAME}"

export OUT_DIR="${SEMAPHORE_PROJECT_DIR}/out"
export IMAGE_OUT="${SEMAPHORE_PROJECT_DIR}/out/arch/arm64/boot/Image.gz-dtb";

if [ -e ${OUT_DIR} ]; then
  echo -e "\n\033[0;32m> OUT folder already exists ! Deleting it.... \033[0;0m\n" ;
  rm -rf ${OUT_DIR};
else
  echo -e "\n\033[0;32m> OUT folder doesn't exist ! Creating it.... \033[0;0m\n" ;
  mkdir -p out;
fi;

$MAKE_STATEMENT O=${OUT_DIR} clean 
$MAKE_STATEMENT O=${OUT_DIR} mrproper 
rm -rf $IMAGE_OUT

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
    echo -e "\n\033[0;31m> Cleaning $KERNEL_WORKING_DIR/.ccache contents\033[0;0m" 
    rm -rf "$KERNEL_WORKING_DIR/.ccache"
  fi
  # If you want to build *without* using ccache
  # run this script with -no-ccache flag
  if [[ "$*" != *"-no-ccache"* ]] 
  then
    export USE_CCACHE=1
    export CCACHE_DIR="$KERNEL_WORKING_DIR/.ccache"
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

# Are we using ccache?
if [ -n "$USE_CCACHE" ] 
then
  CROSS_COMPILE="ccache $CROSS_COMPILE"  
fi

# Build starts here
# =================
if [[ $TC_ID = clang ]]; then
  echo -e "> Opening .config file...\n"
  echo -e "\n\033[0;31m> BUILDING WITH CLANG TOOLCHAIN\033[0;0m\n\n"
make O=${OUT_DIR} ARCH=arm64 santoni_defconfig

PATH="${CDIR}/bin:${TCDIR}/bin:${PATH}" \
make -j$(nproc --all) O=${OUT_DIR} \
                      ARCH=arm64 \
                      SUBARCH=arm64 \
                      CC=${CDIR}/bin/clang \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      CROSS_COMPILE=${KERNEL_WORKING_DIR}/${TCDIR}
echo -e "> Starting Clang kernel compilation using .config file...\n"

start=$SECONDS
else
echo -e "> Opening .config file...\n"
echo -e "\n\033[0;31m> BUILDING WITH NORMAL TOOLCHAIN \033[0;0m\n\n"

ARCH=arm64 SUBARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE 
make O=${OUT_DIR} $DEFCONFIG 
make O=${OUT_DIR} -j$(nproc --all);
echo -e "> Starting kernel compilation using .config file...\n"

start=$SECONDS
fi
# Want custom kernel flags?
# =========================
# KBUILD_KERNEL_CFLAGS: Here you can set custom compilation 
# flags to turn off unwanted warnings, or even set a 
# different optimization level. 
# To see how it works, check the Makefile ... file, 
# line 625 to 628, located in the root dir of this kernel.
KBUILD_KERNEL_CFLAGS="-Wno-misleading-indentation -Wno-bool-compare -mtune=cortex-a53 -march=armv8-a+crc+simd+crypto -mcpu=cortex-a53 -O2" 
KBUILD_KERNEL_CFLAGS=$KBUILD_KERNEL_CFLAGS #ARCH=arm64 SUBARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE $MAKE_STATEMENT -j8

if [[ ! -f "${IMAGE_OUT}" ]]; then
    echo -e "\n\033[0;31m> Image.gz-dtb not FOUND. Build failed \033[0;0m\n";
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="Image.gz-dtb not FOUND. Build failed !. $KERNEL_NAME CI Build stopped unexpectedly ! " -d chat_id=$CHANNEL_ID
    success=false;
    exit 1;
else
    echo -e "\n\033[0;32m> Image.gz-dtb FOUND. Build Successful \033[0;0m\n" ;
    success=true;
    grep "$LC" ${OUT_DIR}/include/generated/compile.h
fi

# Get current kernel version
KERNEL_VERSION=$(head -n3 Makefile | sed -E 's/.*(^\w+\s[=]\s)//g' | xargs | sed -E 's/(\s)/./g')
echo -e "\n\n\033[0;34m> Packing Kernel v$KERNEL_VERSION $ZIP_NAME\n\033[0;0m\n" 

end=$SECONDS
duration=$(( end - start ))
printf "\n\033[0;31m> $KERNEL_NAME CI Build Completed in %dh:%dm:%ds\033[0;0m\n \n" $(($duration/3600)) $(($duration%3600/60)) $(($duration%60)) 

echo -e "\n\033[0;34m> ================== Now, Let's zip it ! ===================\033[0;0m\n \n"

cd $SEMAPHORE_PROJECT_DIR

cp $IMAGE_OUT $SEMAPHORE_PROJECT_DIR/AnyKernel2
cd $SEMAPHORE_PROJECT_DIR/AnyKernel2/
rm -rf zImage 
mv Image.gz-dtb zImage
rm -rf *.zip
zip -r9 ${FINAL_ZIP} *;
cd -;

# Tranfer.sh Function
# ==================
function transfer() {
  zip_name="$(echo $1 | awk -F '/' '{print $NF}')";
  url="$(curl -# -T $1 https://transfer.sh)";
  printf '\n';
  echo -e "\n\033[0;32m> Download ${zip_name} at ${url} \033[0;0m\n" ;
  curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="$url" -d chat_id="$CHANNEL_ID"
}

if [ -f "$FINAL_ZIP" ];
then
echo -e "\n\033[0;32m> $ZIP_NAME zip can be found at $FINAL_ZIP \033[0;0m\n" ;
if [[ ${success} == true ]]; 
then
    echo -e "\n\033[0;34m> Uploading ${ZIP_NAME} to https://transfer.sh/ \033[0;0m\n" ;
    transfer "${FINAL_ZIP}";

# Emojis for Beautification
# ====================
egear="⚙️"
ebeginner="🔰"
eclock="🕐"
ecommit="🗒"
ebook="📕"
source ${OUT_DIR}/include/generated/compile.h 
tctype="$LINUX_COMPILER"


message="$egear $KERNEL_NAME CI Build Successful "
header="$ebeginner BUILD DETAILS : "
branch="$ebook Branch : $DIV_NAME"
time="$eclock Time Taken : $(($duration%3600/60))m:$(($duration%60))s"
commit="$ecommit Last Commit :  
$(git log --pretty=format:'%h : %s' -2)"

curl -F chat_id="$CHANNEL_ID" -F document=@"${ZIP_DIR}/$ZIP_NAME" -F caption="$message 

$header
$branch 
$time
$commit
$tctype" https://api.telegram.org/bot$BOT_API_KEY/sendDocument
curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="CAADBQADuQADLG6EE9HnR-_L0F2YAg" -d chat_id="$CHANNEL_ID"

rm -rf ${ZIP_DIR}/${ZIP_NAME}

fi
else
echo -e "\n\033[0;31m> Zip Creation Failed \033[0;0m\n";
fi

echo -e "\n\n\033[0;32m> ======= Everything went fine =======\033[0;0m\n"