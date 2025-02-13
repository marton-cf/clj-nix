let

  formatArg =
    x:
    if x == null then
      [ ]
    else
      if (builtins.isList x) then
        x else [ x ];
in

{ clj-nix_overlay }:
{
  mkCljCli =
    { jdkDrv
    , java-opts ? [ ]
    , extra-args ? [ ]
    }:
    builtins.filter
      (s: builtins.stringLength s != 0)
      (
        [
          "${jdkDrv.jdk}/bin/java"
        ]
        ++ (formatArg java-opts) ++
        [
          "-jar"
          "${jdkDrv.jarPath}"
        ]
        ++ (formatArg extra-args)
      );

  mkCljApp = { pkgs, modules }:
    let
      pkgs' = pkgs.extend clj-nix_overlay;

      _m = pkgs.lib.evalModules {
        specialArgs = { pkgs = pkgs'; };
        modules =
          [ ./modules/top-level.nix ] ++ modules;
      };

      cfg = _m.config;

      cljDrv = pkgs'.mkCljBin {
        jdkRunner = cfg.jdk;
        inherit (cfg) projectSrc name version main-ns buildCommand
          lockfile java-opts compileCljOpts javacOpts;
      };
    in

    assert (pkgs'.lib.assertMsg
      (cfg.customJdk.enable == true -> cfg.nativeImage.enable == false)
      "customJdk and nativeImage are incompatible, you can enable only one"
    );

    assert (pkgs'.lib.assertMsg
      (cfg.withLeiningen == true -> ! isNull cfg.buildCommand)
      "With Leiningen you have to provide a 'buildCommand'"
    );

    assert (pkgs'.lib.assertMsg
      (cfg.withLeiningen == true -> cfg.compileCljOpts == false && cfg.javacOpts == false)
      "Leiningen is incompatible with Clojure tools.build options (compileCljOpts and javacOpts)"
    );


    if cfg.customJdk.enable then
      pkgs'.customJdk
        {
          inherit cljDrv;
          jdkBase = cfg.jdk;
          java-opts = cfg.java-opts;
          inherit (cfg.customJdk) jdkModules extraJdkModules locales;
        }

    else if cfg.nativeImage.enable then
      pkgs'.mkGraalBin
        {
          inherit cljDrv;
          inherit (cfg.nativeImage) graalvm extraNativeImageBuildArgs graalvmXmx;
        }
    else
      cljDrv;

}
