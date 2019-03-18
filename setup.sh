#!/usr/bin/env bash
install-package ccache bc libncurses5-dev git-core gnupg flex bison gperf \
build-essential zip bzip2 curl libc6-dev ncurses-dev 
echo 'export PATH="/usr/lib/ccache:$PATH"' | tee -a ~/.bashrc 
source ~/.bashrc 
echo $PATH

#GCC Toolchain
wget https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/e54105c9f893a376232e0fc539c0e7c01c829b1e.tar.gz
mkdir -p ~/aarch64-linux-android
tar -xvf e54105c9f893a376232e0fc539c0e7c01c829b1e.tar.gz -C ~/aarch64-linux-android

#Clang Toolchain
wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r353983.tar.gz
mkdir -p ~/linux-x86-master-clang
tar -xvf clang-r353983.tar.gz -C ~/linux-x86-master-clang