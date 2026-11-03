# Renders a Flatpak override file (the `[Context]` / `[Environment]` /
# `[… Bus Policy]` INI dialect that `flatpak override` reads and writes).
#
# The caller passes the evaluated submodule value; fields may be absent (the
# built-in `global` override is assembled by hand), hence the `or` defaults.
{ lib }:
let
  inherit (lib)
    concatStrings
    concatStringsSep
    mapAttrsToList
    optionalString
    ;

  # List values are ';'-separated (flatpak's own writer appends a trailing ';').
  listValue = k: v: optionalString (v != [ ]) "${k}=${concatStringsSep ";" v};\n";

  policyGroup =
    group: v:
    optionalString (v != { }) ("[${group}]\n" + concatStrings (mapAttrsToList (n: p: "${n}=${p}\n") v) + "\n");
in
ctx:
"[Context]\n"
+ listValue "shared" (ctx.shared or [ ])
+ listValue "sockets" (ctx.sockets or [ ])
+ listValue "devices" (ctx.devices or [ ])
+ listValue "features" (ctx.features or [ ])
+ listValue "filesystems" (ctx.filesystems or [ ])
+ listValue "persistent" (ctx.persistent or [ ])
+ listValue "unset-environment" (ctx.unsetEnvironment or [ ])
+ concatStrings (mapAttrsToList (k: v: "${k}=${v}\n") (ctx.extraContext or { }))
+ optionalString ((ctx.environment or { }) != { }) (
  "\n[Environment]\n" + concatStrings (mapAttrsToList (k: v: "${k}=${v}\n") (ctx.environment or { }))
)
+ policyGroup "Session Bus Policy" (ctx.sessionBus or { })
+ policyGroup "System Bus Policy" (ctx.systemBus or { })
