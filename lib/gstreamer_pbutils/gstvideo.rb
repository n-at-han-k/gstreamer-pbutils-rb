# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

# GstVideo -- video format description, overlays and the colour-space helpers
# snapshot uses.
#
# It lives here rather than in a gem of its own because `GstVideo-1.0.typelib`
# ships in the same package as GstPbutils', so this gem already pins everything
# it needs and already has gst_init run by GstPbutils' loader.
module GstVideo
  LOG_DOMAIN = "GstVideo"
  GLib::Log.set_log_domain(LOG_DOMAIN)

  class Error < StandardError
  end

  # Methods in the typelib whose names cannot be Ruby method names, as
  # "Class#name". See {Loader#define_method}.
  UNNAMEABLE_METHODS = []

  class Loader < GObjectIntrospection::Loader
    def load
      self.version = "1.0"
      super("GstVideo")
    end

    private

    # GstVideo has a method named `2d`. The loader defines methods by
    # generating source and class_eval'ing it:
    #
    #     def #{method_name}(*arguments, &block)
    #
    # so a name beginning with a digit is not a NameError but a SyntaxError
    # raised from inside the loader, and it takes down the whole namespace:
    #
    #     SyntaxError: loader.rb:593: syntax errors found
    #     > 593 |         def 2d(*arguments, &block)
    #           |            ^ expected a delimiter to close the parameters
    #
    # Only a leading digit is filtered, not everything that fails
    # /\A[a-z_]/ -- operator names like == and [] are legitimate Ruby method
    # names and must still reach super.
    #
    # The skipped name is recorded rather than silently dropped. Reaching it
    # needs GObjectIntrospection directly; that is a fair trade for having the
    # other several hundred methods in this namespace.
    def define_method(info, klass, method_name)
      if /\A\d/.match?(method_name)
        GstVideo::UNNAMEABLE_METHODS << "#{klass}##{method_name}"
      else
        super
      end
    end
  end

  Loader.new(self).load
end
