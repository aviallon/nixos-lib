{lib
, myLib
}:

rec {
  log2 = let
    mylog = x: y: if (x >= 2) then mylog (x / 2) (y + 1) else y;
  in x: mylog x 0;

  clamp = min_x: max_x: x: lib.min ( lib.max x min_x ) max_x;
}

