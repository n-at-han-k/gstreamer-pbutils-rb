# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

require "English"

require "gobject-introspection"

require_relative "gstreamer_pbutils/version"
require_relative "gstreamer_pbutils/loader"

# Ruby bindings for GStreamer Base Utils, the `libgstpbutils` library that
# ships with gst-plugins-base: the GstDiscoverer, the `gst_codec_utils_*`
# bitstream header parsers, the registry's codec and element descriptions, and
# the encoding profiles.
#
# Base Utils is the part of the GStreamer stack that answers questions *about*
# media rather than moving any, and none of it wants a window or a main loop,
# which is what makes it pleasant to use from a script.
#
# Nothing here wraps a C function by hand. gst-plugins-base ships a GObject
# Introspection typelib describing every class, method, property and signal the
# library has, and ruby-gnome's GObjectIntrospection::Loader reads that at
# require time and defines the Ruby classes from it. {GstPbutils::Loader} is
# the whole binding; what you get is the whole library, and it does not drift
# when gst-plugins-base gains API.
#
# This is how ruby-gnome itself ships gtksourceview5, libsecret and the rest.
#
# The gem is `gstreamer_pbutils` and the module is `GstPbutils`, which is not
# an oversight: the namespace a GI loader defines is the typelib's own, and
# renaming it would put the Ruby docs and the C docs under different names for
# the same class. `GstreamerPbutils::VERSION` is the gem's version and the only
# thing under the gem's own name.
#
# The typelib has to be findable at require time, which means
# gst-plugins-base's `girepository-1.0` directory on `GI_TYPELIB_PATH` or in
# the system default -- along with GStreamer core's, because `GstPbutils-1.0`
# declares `Gst-1.0` as a dependency and the loader resolves that
# transitively. This gem cannot install either: they are C library artefacts
# and belong to the distribution. See the README for the package names;
# `flake.nix` wires up a dev shell that has them.
#
# One trap, paid for already: the typelib must come from the same glib build as
# the `gobject-introspection` gem. Mix two and GObject's types are registered
# twice in one process, which fails as
# `cannot register existing type 'GTlsCertificate'`.
module GstPbutils
  LOG_DOMAIN = "GstPbutils"
  GLib::Log.set_log_domain(LOG_DOMAIN)

  class Error < StandardError
  end

  loader = Loader.new(self)
  loader.load
end
