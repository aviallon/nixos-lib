{config, pkgs, lib, ...}:
with lib;
let
  cfg = config.aviallon.services.jupyterhub;
in
{
  options.aviallon.services.jupyterhub = {
    enable = mkEnableOption "Jupyterhub server with Python 3 kernel";
  };
  
  config = mkIf cfg.enable {
    services.jupyterhub = {
      enable = true;
      kernels.python3 = let
        env = (pkgs.python3.withPackages (pythonPackages: with pythonPackages; [
                ipykernel
                pandas
                scikit-learn
                pyspark
                matplotlib
                numpy
                pip
              ]));
      in {
        displayName = "Python 3 for machine learning";
        argv = [
          "${env.interpreter}"
          "-m"
          "ipykernel_launcher"
          "-f"
          "{connection_file}"
        ];
        language = "python";
        logo32 = "${env}/${env.sitePackages}/ipykernel/resources/logo-32x32.png";
        logo64 = "${env}/${env.sitePackages}/ipykernel/resources/logo-64x64.png";
      };
    };

    services.nginx = {
      enable = true;
    };
    services.nginx.virtualHosts = {
      "jupyterhub.localhost" = {
        listen = [ { addr = "0.0.0.0"; port = 80; } ];
        locations."/" = {
          proxyPass = "http://localhost:${toString config.services.jupyterhub.port}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
