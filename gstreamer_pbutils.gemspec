# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

require_relative "lib/gstreamer_pbutils/version"

Gem::Specification.new do |spec|
  spec.name = "gstreamer_pbutils"
  spec.version = GstreamerPbutils::VERSION
  spec.authors = ["Nathan Kidd"]
  spec.email = ["nathankidd@hey.com"]
  spec.license = "Apache-2.0"

  spec.summary = "Ruby bindings for GStreamer Base Utils: discoverer, encoding profiles and codec descriptions."
  spec.description = "GStreamer Base Utils: discoverer, encoding profiles and codec descriptions, for Ruby. Defined from its GObject "\
    "Introspection typelib at require time rather than wrapped by hand, so the "\
    "binding is the whole library and does not drift as it gains API."
  spec.homepage = "https://github.com/n-at-han-k/gstreamer-pbutils-rb"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "https://n-at-han-k.github.io/gstreamer-pbutils-rb/"

  # LICENSE and NOTICE ship because the Apache License asks for both: section
  # 4(a) wants every recipient given a copy of the licence, and 4(d) wants the
  # attribution notices carried along with it.
  spec.files = Dir.glob(
    ["{lib}/**/*", "LICENSE", "NOTICE", "README.md", "CHANGELOG.md"],
    File::FNM_DOTMATCH,
    base: __dir__,
  )

  spec.require_paths = ["lib"]

  # GemKit::Deprecate declares a deprecation as a dated promise: the replacement, and the version the old name stops existing in.
  spec.add_dependency "gem_kit", "~> 0.2"

  # The loader. This is the whole binding: GObjectIntrospection::Loader reads
  # gst-plugins-base's typelib and defines the GstPbutils namespace from it.
  # glib2 comes along as its dependency and is what GLib::Log and the GObject
  # base classes are.
  #
  # Note this does mean installing compiles C: glib2 and gobject-introspection
  # are native extensions built against glib, so a compiler and glib's headers
  # are needed. What this gem adds on top is nothing, and those two are what
  # every ruby-gnome application already has, since gtk4 depends on them.
  #
  # gst-plugins-base itself is NOT a gem dependency and cannot be: it is a C
  # library and its typelib belongs to the distribution. See the README for the
  # package name.
  #
  # ruby-gnome's `gstreamer` gem is deliberately not a dependency either. It
  # would define the Gst namespace as Ruby classes, which is a genuine
  # convenience for anything that handles a GstCaps -- but it is a native
  # extension compiled against gstreamer's own headers, so depending on it
  # would add exactly the build step this gem is here not to have. gst_init
  # does have to run before the namespace will load; GstPbutils::Loader calls
  # it through the Gst-1.0 typelib in pre_load, which needs no gem. The two
  # compose in either order if a caller does want both.
  spec.add_dependency "gobject-introspection", "~> 4.3"

  spec.add_development_dependency "lefthook", "~> 2.2"
end
