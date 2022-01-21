{config, pkgs, ...}:
{
  environment.systemPackages = [ pkgs.nanorc ];
  programs.nano.syntaxHighlight = false;
  programs.nano.nanorc = ''
    set tabstospaces
    set tabsize 2
    set nowrap
    set smarthome
    set positionlog

    include "${pkgs.nano}/share/nano/*.nanorc"
    include "${pkgs.nanorc}/share/*.nanorc"

    extendsyntax Makefile tabgives "    "
  '';
}
