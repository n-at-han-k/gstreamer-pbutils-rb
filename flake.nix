{
  description = "gstreamer_pbutils — Ruby bindings";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    mine.url = "github:n-at-han-k/flake.nix";
    mine.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, mine, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = mine.lib.${system};

        gemspecFiles = pkgs.runCommand "gstreamer_pbutils-gemspec" { } ''
          mkdir -p $out/lib/gstreamer_pbutils
          cp ${./gstreamer_pbutils.gemspec}         $out/gstreamer_pbutils.gemspec
          cp ${./lib/gstreamer_pbutils/version.rb}  $out/lib/gstreamer_pbutils/version.rb
        '';

        gems = pkgs.bundlerEnv {
          name = "gstreamer_pbutils-gems";
          ruby = pkgs.ruby_3_4;
          gemfile = ./Gemfile;
          lockfile = ./Gemfile.lock;
          gemset = import ./gemset.nix;
          extraConfigPaths = [ "${gemspecFiles}/." ];
        };

        # The namespaces the loader needs at require time: GstPbutils itself,
        # the Gst/GstBase/GstVideo/GstAudio that GstPbutils-1.0 declares as
        # dependencies, and GLib/GObject/Gio under those. The loader resolves
        # the whole chain transitively, so a missing link fails as
        # `Typelib file for namespace 'Gst' not found`.
        #
        # `makeSearchPath` would take each package's *first* output, and both
        # gstreamer's and glib's first output is `bin`, which carries no
        # typelibs -- hence the explicit `.out`.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) [
            pkgs.gst_all_1.gst-plugins-base
            pkgs.gst_all_1.gstreamer
            pkgs.glib
          ]);

        # Where GStreamer looks for the elements it builds pipelines out of.
        # GstPbutils::Discoverer constructs a uridecodebin, so an empty
        # registry is not a degraded mode: the constructor raises
        # `Couldn't create 'uridecodebin' element`. A Nix shell has no
        # /usr/lib/gstreamer-1.0, so this has to be set explicitly.
        pluginPath = pkgs.lib.makeSearchPath "lib/gstreamer-1.0"
          (map (drv: drv.out or drv) [
            pkgs.gst_all_1.gst-plugins-base
            pkgs.gst_all_1.gstreamer
          ]);
      in
      {
        devShells.default = lib.mkRubyShell {
          buildInputs = with pkgs; [
            gems
            gems.wrappedRuby

            # gst-plugins-base for GstPbutils-1.0.typelib and libgstpbutils,
            # gstreamer for the Gst-1.0 typelib it depends on and for the core
            # elements. Taking both from the same nixpkgs as the
            # gobject-introspection gem is not a tidiness point: a typelib
            # built against a different glib registers GObject's types a second
            # time in the process and dies with
            #   cannot register existing type 'GTlsCertificate'
            #
            # There is no pkg-config, no compiler and no -dev input here. The
            # Rust attempt that used to live in this repo needed those to build
            # gstreamer-pbutils-sys; nothing in this gem compiles, and the
            # typelib is read at runtime.
            gst_all_1.gst-plugins-base
            gst_all_1.gstreamer

            skywalking-eyes
          ];

          shellHook = /* bash */ ''
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
            export GST_PLUGIN_SYSTEM_PATH_1_0="${pluginPath}''${GST_PLUGIN_SYSTEM_PATH_1_0:+:$GST_PLUGIN_SYSTEM_PATH_1_0}"

            export BUNDLE_GEMFILE="$PWD/Gemfile"
            export BUNDLE_FROZEN=false

            export LANG="''${LANG:-C.UTF-8}"
            export LC_ALL="''${LC_ALL:-$LANG}"

            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
          '';
        };
      }
    );
}
