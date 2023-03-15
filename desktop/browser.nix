{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
in {
  config = mkIf (cfg.enable && !generalCfg.minimal) {
    environment.systemPackages = with pkgs; []
      ++ optionals (!generalCfg.minimal) [
        chromium
        myFirefox
      ];

    programs.chromium = {
      enable = true;
      # https://docs.microsoft.com/en-us/microsoft-edge/extensions-chromium/enterprise/auto-update
      # https://clients2.google.com/service/update2/crx?x=id%3D{extension_id}%26v%3D{extension_version}
      extensions = [
        # "gcbommkclmclpchllfjekcdonpmejbdp;https://clients2.google.com/service/update2/crx" # HTTPS Everywhere
        "mleijjdpceldbelpnpkddofmcmcaknm" # Smart HTTPS
        "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx" # Ublock Origin
        "fihnjjcciajhdojfnbdddfaoknhalnja" # I don't care about cookies
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
      ];
      extraOpts = {
        "PlatformHEVCDecoderSupport" = true;
        "BrowserSignin" = 0;
        "SyncDisabled" = true;
        "PasswordManagerEnabled" = true;
        "SpellcheckEnabled" = true;
        "SpellcheckLanguage" = [
          "fr"
          "en-US"
        ];
        "DefaultSearchProviderEnabled" = true;
        "DefaultSearchProviderKeyword" = "duckduckgo";
        "DefaultSearchProviderName" = "DuckDuckGo";
        "ExtensionInstallSources" = [
          "https://chrome.google.com/webstore/*"
          "https://microsoftedge.microsoft.com/addons/*"
          "https://gitlab.com/magnolia1234/bypass-paywalls-chrome-clean/*" # */
        ];
        "BuiltInDnsClientEnabled" = false;
        "TranslateEnabled" = false;
        "PasswordLeakDetectionEnabled" = false;
        "CloudPrintProxyEnabled" = false;
        "CloudPrintSubmitEnabled" = false;
        "SafeBrowsingProtectionLevel" = 0; # Force disabled
      };
      defaultSearchProviderSearchURL = ''https://duckduckgo.com/?kp=1&k1=-1&kav=1&kak=-1&kax=-1&kaq=-1&kap=-1&kau=-1&kao=-1&kae=d&q={searchTerms}'';
      defaultSearchProviderSuggestURL = ''https://ac.duckduckgo.com/ac/?q={searchTerms}'';
    };
  };
}
