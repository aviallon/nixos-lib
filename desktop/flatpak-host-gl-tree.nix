# Pure builder for a self-contained flatpak GL `.host` extension.
#
# Turns a NixOS graphics-driver tree (what /run/opengl-driver symlinks to) into
# the layout a flatpak `org.freedesktop.Platform.GL{32,}.host` extension point
# expects, resolves the full transitive library closure so the result works in
# the sandbox (which cannot see /nix/store), and rewrites the absolute store
# paths baked into the vendor JSON.
{
  pkgs,
  name,
  drivers,
  # Path the extension is mounted at inside the sandbox, e.g.
  # /usr/lib/x86_64-linux-gnu/GL/host/lib
  mountLib,
}:
pkgs.runCommand "flatpak-gl-host-${name}"
  {
    nativeBuildInputs = [ pkgs.gawk pkgs.glibc.bin ];
  }
  ''
    set -euo pipefail
    mkdir -p $out/lib

    # 1. Mirror the driver tree. A subdirectory whose root is a symlink into the
    #    store must be copied by *contents*: flatpak refuses a merge-dir that
    #    resolves outside the extension ("Extension … has invalid merge-dirs").
    for sub in dri gbm vdpau d3d; do
      if [ -e "${drivers}/lib/$sub" ]; then cp -r "${drivers}/lib/$sub/." "$out/lib/$sub/"; fi
    done
    for f in "${drivers}"/lib/*.so*; do
      if [ -e "$f" ]; then cp -Lf "$f" "$out/lib/"; fi
    done

    # 2. Map share/ and etc/ onto the extension-point layout.
    copy_dir() { if [ -d "$1" ]; then mkdir -p "$(dirname "$2")"; cp -r "$1/." "$2/"; fi; }
    copy_dir "${drivers}/share/vulkan/icd.d"                "$out/vulkan/icd.d"
    copy_dir "${drivers}/share/vulkan/explicit_layer.d"     "$out/vulkan/explicit_layer.d"
    copy_dir "${drivers}/share/vulkan/implicit_layer.d"     "$out/vulkan/implicit_layer.d"
    copy_dir "${drivers}/share/glvnd/egl_vendor.d"          "$out/glvnd/egl_vendor.d"
    copy_dir "${drivers}/share/egl/egl_external_platform.d" "$out/egl/egl_external_platform.d"
    copy_dir "${drivers}/etc/OpenCL/vendors"                "$out/OpenCL/vendors"
    copy_dir "${drivers}/share/drirc.d"                     "$out/share/drirc.d"

    # 3. Resolve the transitive closure of every shipped .so, minus the core C
    #    runtime (the sandbox already provides libc/libm/libpthread/libdl/…).
    #    The nix libs use DT_RUNPATH (absolute store paths), so once the deps
    #    live in the extension's lib/ — which `add-ld-path = lib` puts in the
    #    ldconfig cache — they resolve.
    : > deps
    while IFS= read -r so; do
      ldd "$so" 2>/dev/null | awk '/=>/ {print $3}' | grep -E '^/nix/store' >> deps || true
    done < <(find "$out/lib" \( -name '*.so' -o -name '*.so.*' \))
    sort -u deps -o deps
    grep -vE '/(libc|libm|libpthread|libdl|librt|libresolv|libnsl|libutil|libthread_db|ld-linux)[.-]' deps > keep || true
    while IFS= read -r dep; do cp -Lf "$dep" "$out/lib/"; done < keep

    # 4. Rewrite absolute store paths in the vendor metadata to the mount path.
    #    (nvidia-x11 writes /nix/store/<pkg>/lib/… into nvidia_icd.json,
    #    10_nvidia.json, nvidia_layers.json and the OpenCL nvidia.icd.)
    chmod -R u+w "$out"
    find "$out" -type f \( -name '*.json' -o -name '*.icd' \) -print0 | while IFS= read -r -d "" f; do      sed -E -i "s#/nix/store/[^/\"]+/lib/#${mountLib}/#g" "$f"
    done
    # …and in symlinks (e.g. lib/gbm/nvidia-drm_gbm.so).
    find "$out" -type l -print0 | while IFS= read -r -d "" l; do
      tgt="$(readlink "$l")"
      case "$tgt" in
        /nix/store/*/lib/*) ln -sfn "${mountLib}/$(basename "$tgt")" "$l" ;;
      esac
    done
  ''
