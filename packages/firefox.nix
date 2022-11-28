{pkgs, lib,
...
}:
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
in pkgs.wrapFirefox pkgs.firefox-esr-unwrapped {
    cfg = {
      smartcardSupport = true;
      pipewireSupport = true;
      ffmpegSupport = true;
      enablePlasmaBrowserIntegration = true;
    };

    extraPolicies = {
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
          "French-GC@grammalecte.net"
        ];             
      };
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
        "French-GC@grammalecte.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/grammalecte-fr/latest.xpi";
        };
      };
      ExtensionUpdate = true;
    }; 

    extraPrefs = traceVal (genPrefList { locked = true; } {
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
      "security.protectionspopup.recordEventTelemetry" = false;
      "security.identitypopup.recordEventTelemetry" = false;
      "security.certerrors.recordEventTelemetry" = false;
      "security.app_menu.recordEventTelemetry" = false;
      "privacy.trackingprotection.origin_telemetry.enabled" = false;
      "browser.ping-centre.telemetry" = false;
      "browser.newtabpage.activity-stream.telemetry" = false;
      "browser.newtabpage.activity-stream.feeds.telemetry" = false;
      "browser.newtabpage.activity-stream.telemetry.structuredIngestion.endpoint" = "";

      "browser.safebrowsing.provider.google.advisoryURL" = "";
      "browser.safebrowsing.provider.google.gethashURL" = "";
      "browser.safebrowsing.provider.google.reportURL" = "";
      "browser.safebrowsing.provider.google.updateURL" = "";
      "browser.safebrowsing.provider.google4.dataSharingURL" = "";
      "browser.safebrowsing.provider.google4.gethashURL" = "";
      "browser.safebrowsing.provider.google4.reportURL" = "";
      "browser.safebrowsing.provider.google4.updateURL" = "";
    } + "\n" + genPrefList {} {
      "intl.accept_languages" =	"fr-fr,en-us,en";
      "intl.locale.requested" = "fr,en-US";
      "media.eme.enabled" = true; # DRM
      "general.autoScroll" = true; # Middleclick scrolling

      "privacy.trackingprotection.enabled" = true;

      "browser.shell.didSkipDefaultBrowserCheckOnFirstRun" = true;

      "media.ffmpeg.vaapi.enabled" = true;
      "media.ffvpx.enabled" = true;
      "media.navigator.mediadatadecoder_vpx_enabled" = true;
      "media.rdd-ffmpeg.enabled" = true;
      "media.rdd-ffvpx.enabled" = true;
      "media.rdd-opus.enabled" = true;
    });
  }
