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
    merkuro # Merkuro is a application suite designed to make handling your emails, calendars, contacts, and tasks simple. (https://invent.kde.org/pim/merkuro)
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
    qrca # Barcode scanner used for scanning WiFi QR codes, among others
  ];
}
