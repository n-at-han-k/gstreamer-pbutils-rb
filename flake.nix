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

        # A second shell for one job the default shell cannot do: install the
        # built gem from scratch and prove it needs no toolchain of its own.
        #
        # The default shell's ruby comes from bundlerEnv, with the bundle
        # already resolved and GEM_HOME inside the read-only store, so
        # `gem install` there fails on permissions and proves nothing either
        # way. This one is a plain ruby with a writable GEM_HOME, which is the
        # situation a user installing the gem is actually in.
        #
        # It is deliberately a devShell rather than an apt-get in the workflow.
        # CI resolving its own glib through Ubuntu's packages is how the
        # `cannot register existing type` trap gets back in by the side door:
        # the typelib and the glib the gems compile against have to come from
        # one place, and the only way to say "one place" and have it stay true
        # is to say it in the flake. It also means this check is runnable
        # locally, with the same command CI runs.
        #
        # Unlike the default shell, this one does carry a compiler, pkg-config
        # and -dev inputs -- not for this gem, which compiles nothing, but for
        # glib2 and gobject-introspection, which are native extensions. That
        # cost is the honest claim the check exists to make: two ruby-gnome
        # extensions, which every ruby-gnome application already builds, and
        # nothing else. Not a Rust toolchain.
        devShells.install-check = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            ruby_3_4
            pkg-config
            gcc
            gnumake
          ];

          buildInputs = with pkgs; [
            # The pkg-config setup hook puts these packages' `dev` outputs on
            # PKG_CONFIG_PATH, which is what the two extensions look for:
            # glib-2.0.pc for glib2 and gobject-introspection-1.0.pc for
            # gobject-introspection. This is the `pkg-config --libs --cflags
            # glib-2.0` that rb-sys-dock could not provide, which is why the
            # Rust binding could not ship from there.
            glib
            gobject-introspection

            # glib-2.0.pc's `Requires.private: sysprof-capture-4, libpcre2-8`.
            # Real pkg-config only follows Requires.private for a static link,
            # but glib2's extconf uses the `pkg-config` *gem*, a pure-Ruby
            # reimplementation that resolves them unconditionally -- so both
            # have to be on PKG_CONFIG_PATH or the build dies with
            # `.pc doesn't exist: <sysprof-capture-4>` from pkg-config.rb,
            # which reads like a missing library and is not one. The .pc lives
            # in `libsysprof-capture`, not in `sysprof`.
            libsysprof-capture
            pcre2

            gst_all_1.gst-plugins-base
            gst_all_1.gstreamer
          ];

          shellHook = /* bash */ ''
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
            export GST_PLUGIN_SYSTEM_PATH_1_0="${pluginPath}''${GST_PLUGIN_SYSTEM_PATH_1_0:+:$GST_PLUGIN_SYSTEM_PATH_1_0}"

            export LANG="''${LANG:-C.UTF-8}"
            export LC_ALL="''${LC_ALL:-$LANG}"
          '';
        };
      }
    );
}
