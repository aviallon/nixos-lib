{ lib, myLib }:
with lib;
let
  requiredFlags = [ ];
  clangSpecificFlags = [
    "-Wunused-command-line-argument"
    "-Wno-error=unused-command-line-argument"
  ];

  genericCompileFlags = [
    "-O2"
    "-feliminate-unused-debug-types" # Smaller binaries
    "-pipe" # Don't use intermediate files
    "--param=ssp-buffer-size=32" # Don't use stack protection for small functions

    "-fasynchronous-unwind-tables" # Better stack traces
    # Perform loop distribution of patterns that can be code generated with calls to a library (activated at O3 and more)
    "-ftree-loop-distribute-patterns"

    "-frecord-gcc-switches" # Record build flags in binary. Also supported by Clang
  ];

  genericPreprocessorFlags = [
    # Use re-entrant libc functions whenever possible
    "-D_REENTRANT"
  ];
  genericLinkerFlags = [
    "-Wl,-sort-common"
  ];
  ltoFlags = { threads ? 1, thin ? false }: [
    # Fat LTO objects are object files that contain both the intermediate language and the object code. This makes them usable for both LTO linking and normal linking.
    "-flto=${toString threads}" # Use -flto=auto to use GNU make’s job server, if available, or otherwise fall back to autodetection of the number of CPU threads present in your system.
    (optionalString (!thin) "-ffat-lto-objects")
    "-fuse-linker-plugin"

    # Stream extra information needed for aggressive devirtualization when running the link-time optimizer in local transformation mode.
    "-fdevirtualize-at-ltrans"
  ];
  expensiveOptimizationFlags = [
    "-O3"
    # Perform interprocedural pointer analysis and interprocedural modification and reference analysis. This option can cause excessive memory and compile-time usage on large compilation units.
    "-fipa-pta"
    "-ftree-vectorize" # "Perform vectorization on trees."
  ];
  moderatelyUnsafeOptimizationFlags = [
    "-O3"
    # Very few programs actually use trapping math (since it's only available on x86)
    "-fno-trapping-math"

    # Math optimizations leading to loss of precision
    "-fassociative-math"
    "-fno-math-errno"
    "-fexcess-precision=fast"
    "-fcx-limited-range"

  ];
  unsafeOptimizationFlags = [
    # The compiler assumes that if interposition happens for functions the overwriting function will have precisely the same semantics (and side effec>
    "-fno-semantic-interposition"
    "-fno-signed-zeros"

    ##### Very aggressive and experimental options ######
    "-fmodulo-sched"
    "-fmodulo-sched-allow-regmoves"
    "-fgcse-sm" # "This pass attempts to move stores out of loops."
    "-fgcse-las" # "global common subexpression elimination pass eliminates redundant loads that come after stores to the same memory location"
    "-fdevirtualize-speculatively" # "Attempt to convert calls to virtual functions to speculative direct calls"

    # Reduce code size, improving cache locality
    "-fira-hoist-pressure" # "Use IRA to evaluate register pressure in the code hoisting pass for decisions to hoist expressions. This option usually results in smaller code, but it can slow the compiler down."
    "-fira-loop-pressure" # "Use IRA to evaluate register pressure in loops for decisions to move loop invariants. This option usually results in generation of faster and smaller code on machines with large register files."
    "-flive-range-shrinkage" # "Attempt to decrease register pressure through register live range shrinkage. This is helpful for fast processors with small or moderate size register sets."
    "-fschedule-insns" # "If supported for the target machine, attempt to reorder instructions to eliminate execution stalls due to required data being unavailable."
    "-fsched-pressure" # "Enable register pressure sensitive insn scheduling before register allocation."
    "-fsched-spec-load" # "Allow speculative motion of some load instructions."
    "-fsched-stalled-insns=4" # Define how many insns (if any) can be moved prematurely from the queue of stalled insns into the ready list during the second scheduling pass"
    "-ftree-loop-ivcanon" # "Create a canonical counter for number of iterations in loops for which determining number of iterations requires complicated analysis."
    "-ftree-loop-im" # "Perform loop invariant motion on trees."
    "-ftree-vectorize" # "Perform vectorization on trees."
  ];

  veryUnsafeOptimizationFlags = [
    # Super experimental
    "-Ofast" # Allow loss of precision in floating point computations
    "-mfpmath=sse+387" # Use both the 8087 FPU and SSE instructions for floating point math
    "-fstdarg-opt" # Optimize the prologue of variadic argument functions with respect to usage of those arguments.
  ];

  automaticallyParallelizeFlags = cores: [
    # Parallelize loops, i.e., split their iteration space to run in n threads.
    # This is only possible for loops whose iterations are independent and can be arbitrarily reordered.
    "-ftree-parallelize-loops=${toString cores}"
    "-fgraphite-identity" # "Enable the identity transformation for graphite."
    "-floop-nest-optimize" # "Enable the isl based loop nest optimizer."
    "-ftree-loop-distribution" # "improve cache performance on big loop bodies and allow further loop optimizations, like parallelization or vectorization, to take place."
    "-floop-parallelize-all" # "Use the Graphite data dependence analysis to identify loops that can be parallelized."
    "-floop-interchange" # "Improve cache performance on loop nest and allow further loop optimizations, like vectorization, to take place"
    "-floop-nest-optimize" # "Calculates a loop structure optimized for data-locality and parallelism."
  ];

  archToX86Level = arch:
    let
      _map = { }
        // genAttrs [
        "nehalem"
        "westmere"
        "sandybridge"
        "ivybridge"
        "silvermont"
        "goldmont"
        "goldmont-plus"
        "tremont"
        "lujiazui"
        "btver2" # Jaguar
        "bdver1" # Bulldozer and Piledriver (AMD FX family)
        "bdver2" # Piledriver
        "bdver3" # Steamroller
        "x86-64-v2"
      ]
        (name: 2)
        // genAttrs [
        "haswell"
        "broadwell"
        "skylake"
        "alderlake"
        "bdver4" # Excavator
        "znver1"
        "znver2"
        "znver3"
        "x86-64-v3"
      ]
        (name: 3)
        // genAttrs [
        "knl"
        "knm"
        "skylake-avx512"
        "cannonlake"
        "icelake-client"
        "icelake-server"
        "cascadelake"
        "cooperlake"
        "tigerlake"
        "sapphirerapids"
        "rocketlake"
        "znver4"
        "x86-64-v4"
      ]
        (name: 4)
      ;
    in
    if (hasAttr arch _map) then _map.${arch} else 1
  ;

  getARMLevel = arch:
    if (! isNull arch) then
      toInt (elemAt (builtins.match "armv([0-9]).+") 0)
    else null;

  # https://go.dev/doc/install/source#environment
  getGOARM = armLevel: if (isNull armLevel) || (armLevel < 5) || (armLevel > 7) then null else armLevel;

  workarounds = {
    # https://www.intel.com/content/dam/support/us/en/documents/processors/mitigations-jump-conditional-code-erratum.pdf
    intel-jump-conditional-code = rec {
      CFLAGS = [
        # Tells the compiler to align branches and fused branches on 32-byte boundaries
        # https://stackoverflow.com/questions/61016077/32-byte-aligned-routine-does-not-fit-the-uops-cache/61016915#61016915
        "-Wa,-mbranches-within-32B-boundaries"
      ];
      CXXFLAGS = CFLAGS;
    };
  };

  addMarchSpecific = march:
    let
      _map = {
        skylake = workarounds.intel-jump-conditional-code;
        kabylake = workarounds.intel-jump-conditional-code;
        amberlake = workarounds.intel-jump-conditional-code;
        coffeelake = workarounds.intel-jump-conditional-code;
      };
    in
    attrByPath [ march ] { } _map;


  cacheTuning = { compiler, l1d ? null, l1i ? null, l1Line ? null, lastLevel ? null }:
    if compiler == "gcc" then [ ]
      ++ optional (! isNull l1d) "--param l1-cache-size=${toString l1d}"
      ++ optional (! isNull l1Line) "--param l1-cache-line-size=${toString l1Line}"
      ++ optional (! isNull lastLevel) "--param l2-cache-size=${toString lastLevel}"
    else
      [ ];


in
rec {

  levelNames = {
    "normal" = 1;
    "slower" = 2;
    "moderately-unsafe" = 3;
    "unsafe" = 4;
    "very-unsafe" = 5;
  };

  addAttrs = pkg: attrs: pkg.overrideAttrs (old:
    (myLib.attrsets.mergeAttrsRecursive old attrs) // {
      passthru = (pkg.passthru or {}) // (attrs.passtru or {});
    }
  );

  optimizePkg = pkg: { level ? "normal"
                     , recursive ? 0
                     , optimizeFlags ? (guessOptimizationFlags pkg)
                     , blacklist ? [ ]
                     , ltoBlacklist ? [ ]
                     , overrideMap ? { }
                     , stdenv ? null
                     , lto ? false
                     , attributes ? null
                     , _depth ? 0
                     , ...
                     }@attrs:
    if _depth > recursive then
      pkg # Max depth reached, return un-modified pkg
    else if isNull pkg then
      pkg # Pkg is null, ignore
    else if ! isDerivation pkg then
      pkg # Pkg is not a derivation, nothing to override/optimize
    else if (hasAttr "overrideAttrs" pkg) then
      let
        _pkgStdenvCC = attrByPath [ "stdenv" "cc" ] null pkg;
        _ltoBlacklisted = any (p: p == getName pkg) ltoBlacklist;
        _lto =
          if (lto && _ltoBlacklisted) then warn "LTO-blacklisted '${getName pkg}'" false
          else lto;
        _stdenvCC = if isNull stdenv then _pkgStdenvCC else stdenv.cc;
        optimizedAttrs = optimizeFlags (attrs // {
          inherit level;
          compiler =
            if isNull _pkgStdenvCC then null
            else if pkg.stdenv.cc.isGNU then "gcc"
            else if pkg.stdenv.cc.isClang then "clang"
            else throw "Unknown compiler '${getName pkg.stdenv.cc}'" null
          ;
          lto = _lto;
          stdenvCC = _stdenvCC;
        });
        _nativeBuildInputs = filter (p: ! isNull p) (pkg.nativeBuildInputs or [ ]);
        _nativeBuildInputsOverriden = forEach _nativeBuildInputs (_pkg:
          let
            _pkgName = myGetName _pkg;
            hasOverride = any (n: n == _pkgName) (attrNames overrideMap);
            _overridePkg = if hasOverride then overrideMap.${_pkgName} else null;
          in
          if hasOverride then
            warn "Replacing build dependency '${_pkgName}' by '${myGetName _overridePkg}'" _overridePkg
          else
            _pkg
        );

        _buildInputs = filter (p: (! isNull p) && (isDerivation p)) (pkg.buildInputs or [ ]);
        _buildInputsOverriden = forEach _buildInputs (_pkg:
          if (any (n: n == myGetName _pkg) blacklist) then
            warn "Skipping blacklisted '${myGetName _pkg}'" _pkg
          else
            optimizePkg _pkg (attrs // {
              inherit level recursive blacklist optimizeFlags stdenv;
              parallelize = null;
              _depth = _depth + 1;
            })
        );
        _pkgStdenvOverridable = attrByPath [ "override" "__functionArgs" "stdenv" ] null pkg;
        _pkgWithStdenv =
          if (isNull _pkgStdenvOverridable) || (isNull stdenv)
          then pkg
          else warn "Replacing stdenv for '${myGetName pkg}'" (pkg.override { inherit stdenv; });

        _pkg = _pkgWithStdenv.overrideAttrs (old:
          {
            buildInputs = _buildInputsOverriden;
            nativeBuildInputs = _nativeBuildInputsOverriden;

          }
          // optionalAttrs (! isNull _stdenvCC && _stdenvCC.isGNU) ({
            AR = "${_stdenvCC.cc}/bin/gcc-ar";
            RANLIB = "${_stdenvCC.cc}/bin/gcc-ranlib";
            NM = "${_stdenvCC.cc}/bin/gcc-nm";
          })
          # Fix issue when CFLAGS is a string
          // optionalAttrs (hasAttr "CFLAGS" old) {
            CFLAGS = if (! isList old.CFLAGS) then [ old.CFLAGS ] else old.CFLAGS;
          }
        );
        _pkgOptimized = addAttrs _pkg optimizedAttrs;
        _pkgFinal =
          if isAttrs attributes then
            addAttrs _pkgOptimized (traceVal attributes)
          else
            _pkgOptimized
          ;
      in
      trace "Optimized ${myGetName pkg} with overrideAttrs at level '${level}' (depth: ${toString _depth}, lto: ${if lto then "true" else "false"})" _pkgFinal
    else if (hasAttr "name" pkg) then
      warn "Can't optimize ${myGetName pkg} (depth: ${toString _depth})" pkg
    else
      throw "Not a pkg: ${builtins.toJSON pkg} (depth: ${toString _depth})" pkg
  ;

  myGetName = pkg:
    if isDerivation pkg
    then getName pkg
    else null;
  #else warn "getName input is not a derivation: '${toString pkg}'" null;

  guessOptimizationFlags = pkg: { ... }@attrs: makeOptimizationFlags ({
    rust = any (p: (myGetName p) == "rustc") pkg.nativeBuildInputs;
    cmake = any (p: (myGetName p) == "cmake") pkg.nativeBuildInputs;
    go = any (p: (myGetName p) == "go") pkg.nativeBuildInputs;
    ninja = any (p: (myGetName p) == "ninja") pkg.nativeBuildInputs;
    autotools = any (p: (myGetName p) == "autoreconf-hook") pkg.nativeBuildInputs;
  } // attrs);

  makeOptimizationFlags =
    { level ? "normal"
    , extraCFlags ? null
    , lto ? false
    , parallelize ? null
    , cpuArch ? null
    , cpuTune ? null
    , ISA ? "amd64"
    , armLevel ? (getARMLevel cpuArch)
    , x86Level ? (archToX86Level cpuArch)
    , check ? false
    , compiler ? "gcc"
    , stdenvCC ? null
    , cpuCores ? 4
    , go ? false
    , rust ? false
    , cmake ? false
    , ninja ? false
    , autotools ? false
    , l1LineCache ? null
    , l1iCache ? null
    , l1dCache ? null
    , lastLevelCache ? null
    , ...
    }:
    let
      levelN = levelNames.${level};
      march =
        if (! isNull cpuArch) then cpuArch
        else if (! isNull cpuTune) then cpuTune
        else "generic";
      uarchTune =
        if (! isNull cpuTune) then cpuTune
        else if (! isNull cpuArch) then cpuArch
        else "generic";
    in myLib.debug.traceValWithPrefix "optimizations" (foldl' myLib.attrsets.mergeAttrsRecursive {} [
    (rec {
      CFLAGS = unique
        ([ ]
        ++ requiredFlags
        ++ optionals (compiler == "clang") clangSpecificFlags
        ++ optionals (levelN >= 1) genericCompileFlags
        ++ optionals (levelN >= 2) expensiveOptimizationFlags
        ++ optionals (levelN >= 3) moderatelyUnsafeOptimizationFlags
        ++ optionals (levelN >= 4) unsafeOptimizationFlags
        ++ optionals (levelN >= 5) veryUnsafeOptimizationFlags
        ++ optionals lto (ltoFlags { threads = myLib.math.log2 cpuCores; })
        ++ optionals (! isNull parallelize) (automaticallyParallelizeFlags parallelize)
        ++ optionals (! isNull extraCFlags) extraCFlags
        ++ optionals (! isNull cpuArch) [ "-march=${cpuArch}" ]
        ++ optionals (! isNull cpuTune) [ "-mtune=${uarchTune}" ]
        ++ cacheTuning {
          inherit compiler;
          l1Line = l1LineCache;
          l1i = l1iCache;
          l1d = l1dCache;
          lastLevel = lastLevelCache;
        });
      CXXFLAGS = CFLAGS;
      CPPFLAGS = []
        ++ optionals (levelN >= 1) genericPreprocessorFlags;
      LDFLAGS = []
        ++ optionals (levelN >= 3) genericLinkerFlags;

      preConfigure = ''
      
        _maxLoad=$(($NIX_BUILD_CORES * 2))
        makeFlagsArray+=("-l''${_maxLoad}")
        
      '';
    })
    (optionalAttrs autotools {
      preConfigure = ''

        configureFlagsArray+=(
          "CFLAGS=$CFLAGS"
          "CXXFLAGS=$CXXFLAGS"
        )
        
      '';
    })
    (optionalAttrs cmake {
      preConfigure = ''
      
        cmakeFlagsArray+=(
          "-DCMAKE_CXX_FLAGS=$CXXFLAGS"
          "-DCMAKE_C_FLAGS=$CFLAGS"
          ${optionalString lto ''
          "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=true"
          ''}
        )
        
      ''
      ;
    })
    (optionalAttrs ninja {
      preConfigure = ''
      
        _maxLoad=$(($NIX_BUILD_CORES * 2))
        ninjaFlagsArray+=("-l''${_maxLoad}")
        
      '';
    })
    (optionalAttrs rust {
      RUSTFLAGS = [ ]
      ++ optionals (levelN >= 2) [ "-C opt-level=3" ]
      ++ optionals lto [ "-C lto=fat" "-C embed-bitcode=on" ]
      ++ optionals (! isNull cpuArch) [ "-C target-cpu=${cpuArch}" ]
        #++ [ "-C embed-bitcode=off" "-C lto=off" ] # Not needed since rust 1.45
        #++ optionals lto [ "-Clinker-plugin-lto" "-Clto" ]
      ;
    })
    (optionalAttrs (!check) {
      doCheck = false;
      doInstallCheck = false;
    })
    (optionalAttrs (go && ISA == "amd64") {
      GOAMD64 = "v${toString x86Level}";
    })
    (optionalAttrs (go && ISA == "arm") {
      GOARM = toString (getGOARM armLevel);
    })
     (optionalAttrs (go && ISA == "i686") {
      GO386 = "sse2";
    })
    (optionalAttrs go {
      GCCGO = "gccgo";
      CGO_CFLAGS_ALLOW = "-f.*";
      CGO_CXXFLAGS_ALLOW = "-f.*";
      CGO_CPPFLAGS_ALLOW = "-D.*";
      CGO_LDFLAGS_ALLOW = "-Wl.*";
    })
    (addMarchSpecific march)
  ])
  ;
}
