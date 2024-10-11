{lib, myLib, ...}:
with lib;
rec {
  getPriority = x:
    if isAttrs x && (attrByPath [ "_type" ] "" x) == "override" then
      getAttr "priority" x
    else
      lib.modules.defaultOverridePriority
    ;
  _getContent = x:
    if isAttrs x && (attrByPath [ "_type" ] "" x) == "override" then
      getAttr "content" x
    else
      x
    ;

  # lower priority = higher precedence. If (comparePriority a b) is positive, b has higher precedence.
  comparePriority = a: b: myLib.debug.traceValWithPrefix "comparePriority" (getPriority a) - (getPriority b);
  mergeAttrsRecursiveWithPriority = a: b:
    let
      _prio = comparePriority a b;
    in
      if _prio == 0 then
        _mergeAttrsRecursive mergeAttrsRecursiveWithPriority a b
      else if _prio > 0 then
        _getContent b
      else
        _getContent a
    ;

  mergeAttrsRecursive = a: b: _mergeAttrsRecursive _mergeAttrsRecursive a b;
  
  _mergeAttrsRecursive = self: a: b: foldAttrs (item: acc:
    if (isNull acc) then
      item
    else if (isList item) then
      if isList acc then
        acc ++ item
      else [ acc ] ++ item
    else if (isString item) then
      acc + item
    else if (isAttrs item) then
      self acc item
    else item
  ) null [ b a ];
}
