{ stdenv, lib, fetchFromGitHub, kernel }:

stdenv.mkDerivation rec {
  pname = "kvdo";

  _tag = "8.1.1.371";
  version = "${_tag}-${kernel.version}";

  src = fetchFromGitHub {
    owner = "dm-vdo";
    repo = "kvdo";
    rev = "${_tag}";
    sha256 = "sha256:1nwprbyql5vzhhgl2zmgnp5ax50ys7crgq8ff11zr8fhcna4fmmw";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  KERNEL_DIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";

  enableParallelBuilding = true;
  dontConfigure = true;

  MAKEFLAGS = with lib; concatStringsSep " " (
    []
      ++ optional enableParallelBuilding "-j$(nproc)"
      ++ optional enableParallelBuilding "-l$(nproc)"
  );

  buildPhase = ''
    BASE_DIR=$(pwd)
    make -C ${KERNEL_DIR} M=$BASE_DIR/uds modules
    make -C ${KERNEL_DIR} M=$BASE_DIR/vdo \
      KBUILD_EXTRA_SYMBOLS=$BASE_DIR/uds/Module.symvers modules
  '';

  installPhase = ''
    modDir=$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/block/
    mkdir -p $modDir
    for d in uds vdo; do
      mv -v $d/*.ko $modDir/
    done
  '';

  hardeningDisable = [ "pic" ];

  meta = with lib; {
    description = "A pair of kernel modules which provide pools of deduplicated and/or compressed block storage";
    homepage = "https://github.com/dm-vdo/kvdo";
    license = licenses.gpl2Only;
    # maintainers = [ maintainers.makefu ];
    platforms = platforms.linux;
  };
}
