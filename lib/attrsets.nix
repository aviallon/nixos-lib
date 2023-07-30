{lib, myLib, ...}:
with lib;
rec {
  mergeAttrsRecursive = a: b: foldAttrs (item: acc:
    if (isNull acc) then
      item
    else if (isList item) then
      if isList acc then
        acc ++ item
      else [ acc ] ++ item
    else if (isString item) then
      acc + item
    else if (isAttrs item) then
      mergeAttrsRecursive acc item
    else item
  ) null [ b a ];
}
