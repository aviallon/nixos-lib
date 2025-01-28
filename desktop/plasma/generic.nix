{ kdePackages }:
{
  commonPackages = with kdePackages; [
    skanpage
    packagekit-qt
    discover
    akonadi
    kmail
    kdepim-addons
    kdepim-runtime
    calendarsupport

    korganizer
    dolphin
    konsole
    kate
    yakuake
    plasma-pa
    ark
    kolourpaint
    krdc
    sddm-kcm
    filelight
  ];
}
