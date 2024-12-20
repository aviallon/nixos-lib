{config, pkgs, lib, ...}:
with lib;
let
  genPrefList = {locked ? false}: prefs:
    let
      prefFuncName = if locked then "lockPref" else "defaultPref";
    in
    concatStringsSep "\n" (
      mapAttrsToList
        (key: value: ''${prefFuncName}(${builtins.toJSON key}, ${builtins.toJSON value});'' )
        prefs
      );
  cfg = config.programs.firefox;
in {
  config = mkIf cfg.enable {
    programs.firefox.wrapperConfig = {
      smartcardSupport = true;
      pipewireSupport = true;
      ffmpegSupport = true;
      privacySupport = true;
    };

    programs.firefox.policies = {
      CaptivePortal = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisableFirefoxAccounts = false;
      FirefoxHome = {
        Pocket = false;
        Snippets = false;
      };
      HardwareAcceleration = true;
      UserMessaging = {
        ExtensionRecommendations = false;
        SkipOnboarding = true;
        WhatsNew = false;
        MoreFromMozilla = false;
      };
      SSLVersionMin = "tls1.2";
      SearchSuggestEnabled = true;
      SearchEngines = {
        Add = [
          {
            Name = "DuckDuckGo";
            URLTemplate = "https://duckduckgo.com/?kp=1&k1=-1&kak=-1&kax=-1&kau=-1&kae=d&kaj=m&kam=osm&kav=1&kf=fw&q={searchTerms}";
            Method = "GET";
            IconURL = "https://duckduckgo.com/favicon.png";
            Description = "Your privacy, simplified";
          }
        ];
        Default = "DuckDuckGo";
      };
      SupportMenu = {
        Title = "Support";
        URL = "mailto:antoine@lesviallon.fr";
        AccessKey = "S";
      };
      Extensions = {
        Install = [
          "uBlock0@raymondhill.net"
          "magnolia@12.34"
        ];             
      };
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
        "magnolia@12.34" = {
          installation_mode = "normal_installed";
          install_url = "https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass_paywalls_clean-latest.xpi&inline=false";
        };
      };
      ExtensionUpdate = true;
    };

    programs.firefox.preferences = {
      "widget.use-xdg-desktop-portal" = true;
      "dom.event.contextmenu.enabled" = true;
      "network.IDN_show_punycode" = true;
      "plugins.enumerable_names" = true;
      "security.identityblock.show_extended_validation" = true;

      "toolkit.telemetry.server" = "";
      "toolkit.telemetry.unified" = false;
      "toolkit.telemetry.shutdownPingSender.enabled" = false;
      "toolkit.telemetry.newProfilePing.enabled" = false;
      "toolkit.telemetry.firstShutdownPing.enabled" = false;
      "toolkit.telemetry.bhrPing.enabled" = false;
      "network.trr.confirmation_telemetry_enabled" = false;
      "toolkit.telemetry.pioneer-new-studies-available" = false;
      "toolkit.telemetry.updatePing.enabled" = false;
      "security.protectionspopup.recordEventTelemetry" = false;
      "security.identitypopup.recordEventTelemetry" = false;
      "security.certerrors.recordEventTelemetry" = false;
      "security.app_menu.recordEventTelemetry" = false;
      "browser.ping-centre.telemetry" = false;
      "browser.urlbar.eventTelemetry.enabled" = false;
      "browser.newtabpage.activity-stream.telemetry" = false;
      "browser.newtabpage.activity-stream.feeds.telemetry" = false;
      "browser.newtabpage.activity-stream.telemetry.structuredIngestion.endpoint" = "";

      "browser.safebrowsing.provider.google.advisoryURL" = "";
      "browser.safebrowsing.provider.google.gethashURL" = "";
      "browser.safebrowsing.provider.google.reportURL" = "";
      "browser.safebrowsing.provider.google.updateURL" = "";
      "browser.safebrowsing.provider.google.lists" = "";
      "browser.safebrowsing.provider.google.reportMalwareMistakeURL" = "";
      "browser.safebrowsing.provider.google.reportPhishMistakeURL" = "";

      "browser.safebrowsing.provider.google4.lists" = "";
      "browser.safebrowsing.provider.google4.dataSharingURL" = "";
      "browser.safebrowsing.provider.google4.gethashURL" = "";
      "browser.safebrowsing.provider.google4.reportURL" = "";
      "browser.safebrowsing.provider.google4.updateURL" = "";
      "browser.safebrowsing.provider.google4.advisoryURL" = "";
      "browser.safebrowsing.provider.google4.dataSharing.enabled" = false;
      "browser.safebrowsing.provider.google4.reportMalwareMistakeURL" = "";
      "browser.safebrowsing.provider.google4.reportPhishMistakeURL" = "";

      "browser.safebrowsing.downloads.enabled" = false;
      "browser.safebrowsing.malware.enabled" = false;
      "browser.safebrowsing.passwords.enabled" = false;
      "browser.safebrowsing.phishing.enabled" = false;

      #"privacy.trackingprotection.origin_telemetry.enabled" = false;

    } // {
      "intl.accept_languages" =	"fr-fr,en-us,en";
      "intl.locale.requested" = "fr,en-US";
      "media.eme.enabled" = true; # DRM
      "general.autoScroll" = true; # Middleclick scrolling

      "privacy.trackingprotection.enabled" = true;
      "privacy.trackingprotection.fingerprinting.enabled" = true;
      "privacy.trackingprotection.cryptomining.enabled" = true;

      "browser.shell.didSkipDefaultBrowserCheckOnFirstRun" = true;

      "gfx.webrender.all" = true; # Required for any HW accel to work.

      "media.ffmpeg.vaapi.enabled" = true;
      "media.navigator.mediadatadecoder_vpx_enabled" = true; # Enable VA-API for WebRTC.
      "media.ffmpeg.vaapi-drm-display.enabled" = true;
      "media.rdd-ffmpeg.enabled" = true;

      "media.ffvpx.enabled" = false; # Needs to be set to false for VA-API to work with VP8/VP9.
      "media.rdd-vpx.enabled" = false; # Needs to be set to **false** for VA-API to work.
      "media.rdd-opus.enabled" = true;

      "widget.use-xdg-desktop-portal.file-picker" = 1;
      "widget.use-xdg-desktop-portal.location" = 1;
      "widget.use-xdg-desktop-portal.mime-handler" = 1;
      "widget.use-xdg-desktop-portal.settings" = 1;
    };
  };
}
