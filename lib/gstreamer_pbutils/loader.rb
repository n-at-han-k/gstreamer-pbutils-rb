# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

module GstPbutils
  # Defines everything in the GstPbutils namespace from `GstPbutils-1.0.typelib`.
  #
  # Modelled on ruby-gnome's own loaders -- see
  # gtksourceview5/lib/gtksourceview5/loader.rb for one that has to call the
  # library's init function first, and libsecret/lib/libsecret/loader.rb for
  # one that does not.
  #
  # The version string is the typelib's rather than the library's release
  # number, and the two often differ: this one is "1.0", from
  # `GstPbutils-1.0.typelib`, which ships in gst-plugins-base 1.28.
  class Loader < GObjectIntrospection::Loader
    def load
      self.version = "1.0"
      super("GstPbutils")
    end

    private

    # Two initialisations have to happen before a single GstPbutils type can be
    # described, and getting either wrong does not fail cleanly. It prints
    # `GLib-CRITICAL **: g_array_append_vals: assertion 'array' failed` from
    # the middle of the load and then segfaults the VM.
    #
    # `gst_init` is the first, and it is not this library's own:
    # `GstPbutils-1.0` declares `Gst-1.0` as a dependency, and GStreamer's type
    # system, plugin registry and value tables do not exist until core is
    # initialised. The GI loader starts registering GTypes immediately, which
    # is what walks off the end of an array core never allocated.
    #
    # `gst_pb_utils_init` is the second, and it is this library's own: it
    # installs the description tables that `pb_utils_get_codec_description` and
    # its neighbours read.
    def pre_load(repository, namespace)
      init_gstreamer(repository)
      init_pb_utils(repository, namespace)
    end

    # Deliberately through the typelib rather than through ruby-gnome's
    # `gstreamer` gem. That gem would define the Gst namespace as Ruby classes,
    # which is a real convenience -- but it is a native extension compiled
    # against gstreamer's headers, so depending on it would add a build step
    # this gem does not otherwise have. Callers who want `Gst::Caps` install it
    # themselves; see the README. `gst_init_check` is idempotent, so calling it
    # here does not conflict with that gem calling it later.
    def init_gstreamer(repository)
      repository.require("Gst", "1.0")

      succeeded, = repository.find("Gst", "init_check").invoke([[$PROGRAM_NAME]])

      raise Error, "gst_init_check failed: GStreamer core is unusable" unless succeeded
    end

    def init_pb_utils(repository, namespace)
      repository.find(namespace, "pb_utils_init").invoke([])
    end

    # `pb_utils_init` is not API for a caller: by the time the namespace exists
    # it has already run. ruby-gnome's own loaders drop their init functions
    # the same way.
    def load_function_info(info)
      case info.name
      when "pb_utils_init"
        # ignore
      else
        super
      end
    end

    def post_load(repository, namespace)
      require_libraries
    end

    def require_libraries
      # GstTag, GstVideo ship in the same package as GstPbutils and need the same
      # gst_init, so they are brought up here rather than given gems of their
      # own. This is what ruby-gnome's gstreamer gem does for GstBase,
      # GstController and GstAudio.
      require_relative "gsttag"
      require_relative "gstvideo"
    end
  end
end
