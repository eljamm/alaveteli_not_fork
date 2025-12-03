{
  lib,
  stdenv,
  bundlerEnv,
  ruby_3_4,
  icu,
  writeShellScript,
  nodejs,
  defaultGemConfig,
  file,
  zlib,
  # TODO: move theme file args here to get rid of one level of function below
  #
  # pass 3 files that represent the *entire* set of gems used
  # by the theme, ie. core alaveteli + theme gems
  themeGemfile,
  themeLockfile,
  themeGemset,
  ...
}:
bundlerEnv {
  name = "gems-for-alaveteli";
  gemdir = ./..;
  ruby = ruby_3_4;
  extraConfigPaths = [ "${./..}/gems" ];
  lockfile = themeLockfile;
  gemfile = themeGemfile;
  gemset =
    let
      # FIXME: when importing here, alaveteli_features path is relative to theme
      # so it can't find the gem. how do we import relative to this file?
      # ./.. points to the alaveteli source root, it's what we want
      rawThemeGems = import themeGemset;
      # TODO: refactor this
      fixedGems = rawThemeGems // {
        alaveteli_features = rawThemeGems.alaveteli_features // {
          source = rawThemeGems.alaveteli_features.source // {
            path = "${toString ./..}/gems/alaveteli_features";
          };
        };
        excel_analyzer = rawThemeGems.excel_analyzer // {
          source = rawThemeGems.excel_analyzer.source // {
            path = "${toString ./..}/gems/excel_analyzer";
          };
        };
      };

      gems = if themeGemset != null then fixedGems else import ../gemset.nix;
    in
    gems
    # add build dependencies for gems alaveteli uses
    // {
      mini_racer = gems.mini_racer // {
        buildInputs = [ icu ];
        dontBuild = false;
        NIX_LDFLAGS = "-licui18n";
      };
      libv8-node =
        let
          noopScript = writeShellScript "noop" "exit 0";
          linkFiles = writeShellScript "link-files" ''
            cd ../..

            mkdir -p vendor/v8/${stdenv.hostPlatform.system}/libv8/obj/
            ln -s "${nodejs.libv8}/lib/libv8.a" vendor/v8/${stdenv.hostPlatform.system}/libv8/obj/libv8_monolith.a

            ln -s ${nodejs.libv8}/include vendor/v8/include

            mkdir -p ext/libv8-node
            echo '--- !ruby/object:Libv8::Node::Location::Vendor {}' >ext/libv8-node/.location.yml
          '';
        in
        gems.libv8-node
        // {
          dontBuild = false;
          postPatch = ''
            cp ${noopScript} libexec/build-libv8
            cp ${noopScript} libexec/build-monolith
            cp ${noopScript} libexec/download-node
            cp ${noopScript} libexec/extract-node
            cp ${linkFiles} libexec/inject-libv8
          '';
        };
    };

  gemConfig = defaultGemConfig // {
    mahoro = attrs: { nativeBuildInputs = [ file ]; };
    xapian-full-alaveteli = attrs: { nativeBuildInputs = [ zlib ]; };
    statistics2 = attrs: {
      buildFlags = [ "--with-cflags=-Wno-error=implicit-int" ];
    };
  };
}
