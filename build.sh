#!/usr/bin/env bash
#
# Copyright (C) 2023 Kneba <abenkenary3@gmail.com>
#

#
# Function to show an informational message
#

msg() {
	echo
    echo -e "\e[1;32m$*\e[0m"
    echo
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

cdir() {
	cd "$1" 2>/dev/null || \
		err "The directory $1 doesn't exists !"
}

# Main
MainPath="$(pwd)"
MainClangPath="${MainPath}/clang"
ClangPath="${MainClangPath}"
#MainGCCaPath="${MainPath}/GCC64"
#MainGCCbPath="${MainPath}/GCC32"
#GCCaPath="${MainGCCaPath}"
#GCCbPath="${MainGCCbPath}"

# Identity
VERSION=4.19.300
KERNELNAME=TheOneMemory
CODENAME=Hayzel
VARIANT=EAS
BASE=CLO

# Show manufacturer info
MANUFACTURERINFO="ASUSTek Computer Inc."

# Changelogs
CL_URL="https://github.com/Tiktodz/android_kernel_asus_sdm660-4.19/commits/r2/s"

# Clone Kernel Source
git clone --recursive https://$USERNAME:$TOKEN@github.com/Tiktodz/android_kernel_asus_sdm660-4.19 kernel

# Clone Snapdragon Clang
ClangPath=${MainClangPath}
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
mkdir $ClangPath
rm -rf $ClangPath/*
msg "|| Cloning sdclang toolchain ||"
git clone --depth=1 https://gitlab.com/varunhardgamer/trb_clang -b 17 $ClangPath

# Clone GCC
#mkdir $GCCaPath
#mkdir $GCCbPath

#msg "|| Cloning GCC 4.9.x toolchain ||"
#git clone --depth=1 https://github.com/Kneba/aarch64-linux-android-4.9 $GCCaPath
#git clone --depth=1 https://github.com/Kneba/arm-linux-androideabi-4.9 $GCCbPath

# Prepare
KERNEL_ROOTDIR=$(pwd)/kernel # IMPORTANT ! Fill with your kernel source root directory.
export KBUILD_BUILD_USER=queen # Change with your own name or else.
export LD=ld.lld
export LD_LIBRARY_PATH=$ClangPath/lib
IMAGE=$(pwd)/kernel/out/arch/arm64/boot/Image.gz-dtb
ClangMoreStrings="AR=llvm-ar NM=llvm-nm AS=llvm-as STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf HOSTAR=llvm-ar HOSTAS=llvm-as LD_LIBRARY_PATH=$ClangPath/lib LD=ld.lld HOSTLD=ld.lld"
export TZ=Asia/Jakarta
DATE=$(date +"%Y-%m-%d")
START=$(date +"%s")

# Java
command -v java > /dev/null 2>&1

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

# Telegram messaging
tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TG_CHAT_ID" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="$1"
}
# Compiler
compile(){
cd ${KERNEL_ROOTDIR}
msg "|| Cooking kernel. . . ||"
export HASH_HEAD=$(git rev-parse --short HEAD)
export COMMIT_HEAD=$(git log --oneline -1)
make -j$(nproc) O=out ARCH=arm64 asus/X00TD_defconfig
make -j$(nproc) ARCH=arm64 SUBARCH=arm64 O=out \
     PATH=$ClangPath/bin:${PATH} \
     CC=clang \
     CROSS_COMPILE=aarch64-linux-gnu- \
     HOSTCC=clang \
     HOSTCXX=clang++ ${ClangMoreStrings}

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi

   msg "|| Cloning AnyKernel ||"
   git clone https://github.com/Tiktodz/AnyKernel3 -b hmp AnyKernel
   cp $IMAGE AnyKernel
}
# Push kernel to telegram
function push() {
    cd AnyKernel
    curl -F document="@$ZIP_FINAL.zip" "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="🔐<b>Build Done</b>
        - <code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s)... </code>

        <b>📅 Build Date: </b>
        -<code>$DATE</code>

        <b>🐧 Linux Version: </b>
        -<code>$VERSION</code>

         <b>💿 Compiler: </b>
        -<code>$KBUILD_COMPILER_STRING</code>

        <b>📱 Device: </b>
        -<code>$DEVICE_CODENAME($MANUFACTURERINFO)</code>

        <b>🆑 Changelog: </b>
        - <code>%0A<a href='$CL_URL'>Here</a></code>
        <b></b>
        #$KERNELNAME #$CODENAME #$VARIANT"
}
# Find Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="❌ Tetap menyerah...Pasti bisa!!!"
    exit 1
}
# Zipping
function zipping() {
    cd AnyKernel || exit 1

    zip -r9 $KERNELNAME-$CODENAME-$VARIANT-$BASE-"$DATE" * -x .git README.md anykernel.sh .gitignore zipsigner* *.zip

    ZIP_FINAL="$KERNELNAME-$CODENAME-$VARIANT-$BASE-$DATE"

    msg "|| Signing Zip ||"
    tg_post_msg "<code>🔑 Signing Zip file with AOSP keys..</code>"

    curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
    java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
    ZIP_FINAL="$ZIP_FINAL-signed"
    cd ..
}

compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
