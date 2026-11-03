# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

# GstTag -- tag reading and writing -- the metadata nautilus shows for a media file.
#
# It lives here rather than in a gem of its own because `GstTag-1.0.typelib`
# ships in the same package as GstPbutils's, so this gem already pins everything
# it needs and already has gst_init run by GstPbutils's loader. A separate gem
# would add a repository, a release and a dependency for twenty lines.
module GstTag
  LOG_DOMAIN = "GstTag"
  GLib::Log.set_log_domain(LOG_DOMAIN)

  class Error < StandardError
  end

  # Modelled on ruby-gnome's gstreamer gem, which brings up GstBase,
  # GstController and GstAudio behind Gst in exactly this way.
  class Loader < GObjectIntrospection::Loader
    def load
      self.version = "1.0"
      super("GstTag")
    end
  end

  Loader.new(self).load
end
