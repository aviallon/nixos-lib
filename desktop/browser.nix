{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.aviallon.desktop;
  generalCfg = config.aviallon.general;
  vdhcoapp = pkgs.nur.repos.wolfangaukang.vdhcoapp;
in {
  options.aviallon.desktop.browser = {
    firefox.overrides = mkOption {
      internal = true;
      description = "Override firefox package settings";
      type = types.attrs;
      default = {};
      example = { enablePlasmaIntegration = true; };
    };
  };

  config = mkIf (cfg.enable && !generalCfg.minimal) {
    environment.systemPackages = with pkgs; [
        chromium
        # firefox is added by plasma or gnome

        vdhcoapp
      ];

    aviallon.desktop.browser.firefox.overrides.extraNativeMessengingHosts = [
      vdhcoapp
    ];

    environment.etc = with builtins; let
      vdhcoappManifestFile = unsafeDiscardStringContext (readFile "${vdhcoapp}/etc/chromium/native-messaging-hosts/net.downloadhelper.coapp.json");
      vdhcoappManifest = fromJSON (toString vdhcoappManifestFile);
      moddedManifest = toJSON (recursiveUpdate vdhcoappManifest {
        allowed_origins = vdhcoappManifest.allowed_origins ++ [ "chrome-extension://jmkaglaafmhbcpleggkmaliipiilhldn/" ];
      });
      manifestFile = pkgs.writeText "${vdhcoappManifest.name}.json" moddedManifest;
    in {
      "chromium/native-messaging-hosts/net.downloadhelper.coapp.json".source =
        "${manifestFile}";
    };

    programs.chromium = {
      enable = true;
      # https://docs.microsoft.com/en-us/microsoft-edge/extensions-chromium/enterprise/auto-update
      # Chrome Web Store: https://clients2.google.com/service/update2/crx?x=id%3D{extension_id}%26v%3D{extension_version}
      # Edge Web Store: https://edge.microsoft.com/extensionwebstorebase/v1/crx
      extensions = [
        # "gcbommkclmclpchllfjekcdonpmejbdp;https://clients2.google.com/service/update2/crx" # HTTPS Everywhere
        "mleijjdpceldbelpnpkddofmcmcaknm" # Smart HTTPS
        "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx" # Ublock Origin
        "fihnjjcciajhdojfnbdddfaoknhalnja" # I don't care about cookies
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader

        "lkbebcjgcmobigpeffafkodonchffocl;https://gitlab.com/magnolia1234/bypass-paywalls-chrome-clean/-/raw/master/updates.xml" # Bypass Paywalls

        "jmkaglaafmhbcpleggkmaliipiilhldn;https://edge.microsoft.com/extensionwebstorebase/v1/crx" # Video DownloadHelper (Edge)
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
