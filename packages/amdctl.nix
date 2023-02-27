{
stdenv,
cmake,
fetchFromGitHub
}:
stdenv.mkDerivation rec {
  name = "amdctl";
  version = "0.11";

  nativeBuildInputs = [
    cmake
  ];
  
  src = fetchFromGitHub {
    owner = "kevinlekiller";
    repo = "amdctl";
    rev = "v${version}";
    sha256 = "sha256-2wBk/9aAD7ARMGbcVxk+CzEvUf8U4RS4ZwTCj8cHNNo=";
  };

  installPhase = ''
    mkdir -p $out/bin
    cp amdctl $out/bin
  '';
}
