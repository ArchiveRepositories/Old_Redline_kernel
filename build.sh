export PATH="$HOME/proton/bin:$PATH"
SECONDS=0
ZIPNAME="Redline-Reborn-R-Onclite-$(date '+%Y%m%d-%H%M').zip"

if ! [ -d "$HOME/proton" ]; then
echo "Proton clang not found! Cloning..."
if ! git clone -q https://github.com/kdrag0n/proton-clang --depth=1 --single-branch ~/proton; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

mkdir -p out
make O=out ARCH=arm64 onc-perf_defconfig

if [[ $1 == "-r" || $1 == "--regen" ]]; then
cp out/.config arch/arm64/configs/onc-perf_defconfig
echo -e "\nRegened defconfig succesfully!"
exit 0
else
echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image.gz-dtb dtbo.img
fi

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
git clone -q https://github.com/johnmart19/AnyKernel3 -b lto
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3

OUTDIR="$HOME/redline/out/"
VENDOR_MODULEDIR="$KERNEL_DIR/AnyKernel3/modules/vendor/lib/modules"

STRIP="$HOME/proton/aarch64-linux-gnu/bin/strip$(echo "$(find "$HOME/proton/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
            sed -e 's/gcc/strip/')"
for MODULES in $(find "${OUTDIR}" -name '*.ko'); do
    "${STRIP}" --strip-unneeded --strip-debug "${MODULES}"
    "${OUTDIR}"/scripts/sign-file sha512 \
            "${OUTDIR}/certs/signing_key.pem" \
            "${OUTDIR}/certs/signing_key.x509" \
            "${MODULES}"
    find "${OUTDIR}" -name '*.ko' -exec cp {} "${VENDOR_MODULEDIR}" \;
done

cp out/arch/arm64/boot/dtbo.img AnyKernel3
cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
cd ..
rm -rf AnyKernel3
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
if command -v gdrive &> /dev/null; then
gdrive upload --share $ZIPNAME
else
echo "Zip: $ZIPNAME"
fi
rm -rf out/arch/arm64/boot
else
echo -e "\nCompilation failed!"
fi
