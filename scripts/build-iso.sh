#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
cd "$repo_root"

archive="$repo_root/tools/limine-v10.x-binary.zip"
kernel="$repo_root/target/x86_64-os/release/kernel"
iso="$repo_root/build/QOSAMI-OS-x86_64.iso"

for tool in cargo unzip xorriso sha256sum grep du cut mktemp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required tool is missing: %s\n' "$tool" >&2
        exit 1
    fi
done

if [[ ! -f "$archive" ]]; then
    printf 'Limine binary archive is missing: %s\n' "$archive" >&2
    exit 1
fi

mkdir -p "$repo_root/build"
if [[ -e "$iso" ]]; then
    printf 'Refusing to overwrite existing ISO: %s\n' "$iso" >&2
    exit 1
fi

printf 'Building QOSAMI Core (release)...\n'
cargo build -Z build-std=core,alloc -p qosami-core --release

if [[ ! -f "$kernel" ]]; then
    printf 'Kernel binary was not produced: %s\n' "$kernel" >&2
    exit 1
fi

stage="$(mktemp -d "$repo_root/build/qosami-iso-root.XXXXXX")"
report="$(mktemp "$repo_root/build/qosami-iso-report.XXXXXX")"
trap 'rm -rf -- "$stage"; rm -f -- "$report"' EXIT HUP INT TERM

mkdir -p "$stage/boot" "$stage/EFI/BOOT"
cp -- "$kernel" "$stage/boot/kernel"
cp -- "$repo_root/limine.conf" "$stage/limine.conf"

unzip -p "$archive" Limine-10.x-binary/BOOTX64.EFI > "$stage/EFI/BOOT/BOOTX64.EFI"
unzip -p "$archive" Limine-10.x-binary/limine-uefi-cd.bin > "$stage/boot/limine-uefi-cd.bin"

printf 'Creating UEFI-bootable ISO...\n'
xorriso -as mkisofs \
    -R -r -J \
    --efi-boot boot/limine-uefi-cd.bin \
    -efi-boot-part \
    --efi-boot-image \
    --protective-msdos-label \
    "$stage" \
    -o "$iso" >"$report" 2>&1 || {
        cat "$report" >&2
        exit 1
    }

if ! xorriso -indev "$iso" -report_el_torito plain >"$report" 2>&1; then
    cat "$report" >&2
    exit 1
fi

if ! grep -qi 'UEFI' "$report"; then
    cat "$report" >&2
    printf 'ISO was created, but xorriso did not report a UEFI boot entry.\n' >&2
    exit 1
fi

printf '\nISO created and UEFI boot entry verified:\n%s\n' "$iso"
printf 'Size: '
du -h -- "$iso" | cut -f1
printf 'SHA-256: '
sha256sum -- "$iso"
