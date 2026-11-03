# gstreamer_pbutils

Ruby bindings for [GStreamer Base Utils](https://gstreamer.freedesktop.org/documentation/pbutils/),
the `libgstpbutils` library that ships with gst-plugins-base.

Base Utils is the part of the GStreamer stack that answers questions *about*
media rather than moving any, and none of it wants a window or a main loop.

```ruby
require "gstreamer_pbutils"

# What profile and level does this H.264 SPS declare?
GstPbutils.codec_utils_h264_get_level_idc("4.1")      # => 41

# What is in this two-byte AAC AudioSpecificConfig?
GstPbutils.codec_utils_aac_get_profile("\x12\x10".b)  # => "lc"

# What streams does a file actually contain?
discoverer = GstPbutils::Discoverer.new(5 * 1_000_000_000) # 5s, in nanoseconds
info = discoverer.discover_uri("file:///tmp/clip.mp4")
info.stream_list.map(&:caps)
```

The gem is `gstreamer_pbutils`; the module is `GstPbutils`. That is the
typelib's own name for the namespace, and renaming it would put the Ruby docs
and the C docs under different names for the same class.

## How this works

gst-plugins-base ships a GObject Introspection typelib that describes every
class, method, property and signal `libgstpbutils` has. `GstPbutils::Loader`
hands that typelib to ruby-gnome's `GObjectIntrospection::Loader`, which
defines the Ruby classes from it at `require` time.

So this gem has no extension of its own: no C, no Cargo workspace, no
per-platform binary. You get the whole library rather than the subset somebody
got round to wrapping by hand, and it does not drift when gst-plugins-base
gains API.

It is worth being precise about what that does and does not buy you at install
time. `gem install gstreamer_pbutils` still compiles C, because
`gobject-introspection` and `glib2` are themselves native extensions built
against glib — so a compiler and glib's development headers are needed. What
this gem adds on top of that is nothing: those two are what every ruby-gnome
application already has, since `gtk4` depends on them. If you are writing a
Ruby GTK app, this gem costs you no build step you were not already paying.

This is how [ruby-gnome](https://github.com/ruby-gnome/ruby-gnome) itself ships
gtksourceview5, libsecret and the rest.

## What you must install

Two things, and the gem can install neither — both are C-library artefacts and
belong to your distribution:

- **the typelibs**, `GstPbutils-1.0.typelib` and the `Gst-1.0.typelib` it
  declares as a dependency;
- **a plugin registry**, because `GstPbutils::Discoverer` builds a
  `uridecodebin` and raises `Couldn't create 'uridecodebin' element` without
  one. The `codec_utils_*` parsers and the description functions do not need it.

| | |
|---|---|
| Debian / Ubuntu | `gir1.2-gst-plugins-base-1.0`, `gir1.2-gstreamer-1.0`, `gstreamer1.0-plugins-base` |
| Fedora | `gstreamer1-plugins-base-devel`, `gstreamer1-devel` (the typelibs are in the `-devel` packages) |
| Arch | `gst-plugins-base`, `gstreamer` |
| nix | `pkgs.gst_all_1.gst-plugins-base`, `pkgs.gst_all_1.gstreamer` |

If the typelibs are not in the default search path, point `GI_TYPELIB_PATH` at
the directories holding them, and `GST_PLUGIN_SYSTEM_PATH_1_0` at the
`gstreamer-1.0` plugin directories. The dev shell in `flake.nix` does both.

**One trap worth knowing.** The typelib must come from the same glib build as
the `gobject-introspection` gem. Mixing two registers GObject's types twice in
one process and fails with `cannot register existing type 'GTlsCertificate'`.
Under nix, take both from one nixpkgs — and note that glib's and gstreamer's
typelibs are in their `out` output, not the default `bin` one.

## On the `gstreamer` gem

`GstPbutils-1.0` depends on `Gst-1.0`, and GStreamer core has to be initialised
before a single pbutils type can even be described. The loader does that
through the `Gst-1.0` typelib directly, so there is no gem dependency on
ruby-gnome's `gstreamer`.

Add that gem yourself if you want the `Gst` namespace as Ruby classes — which
you will, as soon as you want to build a `Gst::Caps` to pass to
`GstPbutils.pb_utils_get_codec_description`, or to read the `caps` off a
discovered stream as anything richer than an opaque handle. It is a native
extension compiled against gstreamer's headers, which is exactly why it is not
a dependency here: this gem would then carry a build step it does not need.
`gst_init_check` is idempotent, so the two compose in either order.

## Using it from a flake

The gem needs `GstPbutils-1.0.typelib` and everything that typelib declares, resolved
transitively by the loader at `require` time. A missing one surfaces as
`Typelib file for namespace 'X' not found`, one at a time, so the whole chain
is listed here rather than discovered by repeated failure:

- `pkgs.gst_all_1.gst-plugins-base` — GstPbutils-1.0, plus GstVideo, GstAudio and GstTag, which is where `GstPbutils-1.0.typelib` lives
- `pkgs.gst_all_1.gstreamer` — Gst-1.0, and the gst_init this namespace cannot load without
- `pkgs.glib` — GLib-2.0, GObject-2.0 and Gio-2.0, which nearly every GNOME typelib declares

Note the `.out`: a package's default output is often `bin`, which carries no
typelibs. `makeSearchPath` takes the first output, so it has to be asked for
`out` explicitly — this is the single most common way to get a search path that
looks right and finds nothing.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
        (map (drv: drv.out or drv) [ pkgs.gst_all_1.gst-plugins-base pkgs.gst_all_1.gstreamer pkgs.glib ]);
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.ruby_3_4 pkgs.bundler ] ++ [ pkgs.gst_all_1.gst-plugins-base pkgs.gst_all_1.gstreamer pkgs.glib ];

        shellHook = ''
          export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
        '';
      };
    };
}
```

Everything must come from **one** nixpkgs. A typelib built against a different
glib than the `gobject-introspection` gem registers GIO twice in the process
and fails with `cannot register existing type 'GTlsCertificate'`.

If you are packaging an application rather than entering a shell, the same
`typelibPath` goes on the wrapper:

```nix
makeWrapper ${ruby}/bin/ruby $out/bin/my-app \
  --set GI_TYPELIB_PATH "${typelibPath}"
```

## Development

```sh
nix develop
bin/test
```

## Releasing

```sh
gem kit release
```

That is the whole thing. It gates on the changelog having an entry for this
version, on no deprecation deadline coming due, and on a clean working tree;
then builds, pushes and tags.

There is nothing to wait for in CI. This gem is pure Ruby, so `gem build`
produces one `gstreamer_pbutils-X.Y.Z.gem` that is the same artefact wherever it is built —
no extension, no per-platform gems, nothing for a workflow to hand back.


## Licence

Apache-2.0. gst-plugins-base itself is LGPL-2.1-or-later; this gem links
nothing and copies no GStreamer code — it reads a description of it at runtime.
