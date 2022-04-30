{pkgs, lib,
...
}:
with lib;
let
  genPrefList = {locked ? false}: prefs:
    let
      prefFuncName = if locked then "lockPref" else "user_pref";
    in
    concatStringsSep "\n" (
      mapAttrsToList
        (key: value: ''lockPref(${toString key}, ${builtins.toJSON value});'' )
        prefs
      );
in pkgs.wrapFirefox pkgs.firefox-esr-unwrapped {
    cfg = {
      smartcardSupport = true;
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
        ];             
      };
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
      };
      ExtensionUpdate = true;
    }; 

    extraPrefs = genPrefList { locked = true; } {
      "intl.accept_languages" = "";
      "widget.use-xdg-desktop-portal" = true;
      "dom.event.contextmenu.enabled" = true;
      "network.IDN_show_punycode" = true;
      "plugins.enumerable_names" = true;
      "security.identityblock.show_extended_validation" = true;
    }
    + "\n" + genPrefList { } {

    };
  }
