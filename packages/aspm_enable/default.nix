{lib
,bc
,pciutils
,gnugrep
,coreutils
,bash
,writeText
,stdenv
,substituteAll
}:
with lib;
stdenv.mkDerivation rec {
  pname = "aspm_enable";
  version = "2022-04-09";

  src = ./src;

  installPhase = ''
    mkdir -p $out/bin;
    cp -v aspm_enable.sh $out/bin/aspm_enable
    substituteInPlace $out/bin/aspm_enable \
      --replace bc ${bc}/bin/bc \
      --replace lspci ${pciutils}/bin/lspci \
      --replace setpci ${pciutils}/bin/setpci \
      --replace grep ${gnugrep}/bin/grep;
    substituteAllInPlace $out/bin/aspm_enable;
  '';

  buildInputs = [ pciutils bc coreutils gnugrep ];

  meta = {
    description = "A program to forcibly enable PCIe ASPM for compatible devices";
    homepage = "https://wireless.wiki.kernel.org/en/users/Documentation/ASPM";
    license = licenses.gpl3Plus;
    patforms = [ "x86_64-linux" "i686-linux" "aarch64-linux" "mipsel-linux" ];
    maintainers = with maintainers; [ ];
  };
}
