# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

require "gstreamer_pbutils"

describe GstPbutils do
  it "defines the namespace from the typelib" do
    # Not an arbitrary number: it is the point of the loader. A hand-written
    # binding exposes what someone got round to wrapping; this exposes what
    # libgstpbutils has. If the typelib loaded at all this is in the dozens,
    # and a drop to single digits means the loader silently half-ran.
    expect(GstPbutils.constants.size).to be > 25
  end

  it "defines the classes a caller actually reaches for" do
    expect(GstPbutils.const_defined?(:Discoverer)).to be == true
    expect(GstPbutils.const_defined?(:DiscovererInfo)).to be == true
    expect(GstPbutils.const_defined?(:DiscovererVideoInfo)).to be == true
    expect(GstPbutils.const_defined?(:EncodingContainerProfile)).to be == true
    expect(GstPbutils.const_defined?(:EncodingTarget)).to be == true
  end

  it "defines the enumerations, not only the classes" do
    expect(GstPbutils::DiscovererResult.const_defined?(:OK)).to be == true
  end

  it "maps GObject methods onto the classes, not just constants" do
    # A loader that registered the types but no methods would still satisfy
    # every assertion above, so this is the one that catches a half-load.
    expect((GstPbutils::Discoverer.instance_methods - Object.instance_methods).size).to be > 20
    expect((GstPbutils::DiscovererInfo.instance_methods - Object.instance_methods).size).to be > 20
  end

  it "maps namespace-level functions onto the module" do
    expect(GstPbutils.singleton_methods).to be(:include?, :codec_utils_h264_get_level_idc)
    expect(GstPbutils.singleton_methods).to be(:include?, :pb_utils_get_codec_description)
  end

  # The one call here that needs neither a plugin registry nor a parse: it
  # reads a constant compiled into libgstpbutils. So it is also the only thing
  # true unconditionally, which makes it the proof that the loader found and
  # opened the real library rather than just its description.
  it "reports the gst-plugins-base it loaded" do
    expect(GstPbutils.plugins_base_version_string).to be_a(String)

    major, minor, _micro, _nano = GstPbutils.plugins_base_version

    expect(major).to be == 1
    expect(minor).to be_a(Integer)
  end

  describe "the codec_utils bitstream parsers" do
    # 0x12 0x10 is the canonical two-byte AAC AudioSpecificConfig: object type
    # 2 (AAC-LC), sample rate index 4 (44100), 2 channels. It is short enough
    # to write down and is what every AAC-in-MP4 file carries, so it exercises
    # the parsers without a fixture.
    let(:aac_lc_44100_stereo) { "\x12\x10".b }

    it "parses a two-byte AAC AudioSpecificConfig" do
      expect(GstPbutils.codec_utils_aac_get_profile(aac_lc_44100_stereo)).to be == "lc"
      expect(GstPbutils.codec_utils_aac_get_sample_rate(aac_lc_44100_stereo)).to be == 44_100
      expect(GstPbutils.codec_utils_aac_get_channels(aac_lc_44100_stereo)).to be == 2
    end

    # The sample-rate table is a lookup, not a parse, so both directions are
    # exact and the round trip is the property.
    it "round-trips the AAC sample-rate table" do
      index = GstPbutils.codec_utils_aac_get_index_from_sample_rate(48_000)

      expect(index).to be == 3
      expect(GstPbutils.codec_utils_aac_get_sample_rate_from_index(index)).to be == 48_000
    end

    # -1 rather than an exception: the C function's documented way of saying
    # "not in the table", and 44101 genuinely is not.
    it "reports a rate outside the AAC table as -1" do
      expect(GstPbutils.codec_utils_aac_get_index_from_sample_rate(44_101)).to be == -1
    end

    it "maps an H.264 level nickname to its level_idc" do
      expect(GstPbutils.codec_utils_h264_get_level_idc("4.1")).to be == 41
      expect(GstPbutils.codec_utils_h264_get_level_idc("3")).to be == 30
    end

    it "reports a level it does not know as 0 rather than raising" do
      expect(GstPbutils.codec_utils_h264_get_level_idc("not-a-level")).to be == 0
    end
  end

  # Instantiating a GstDiscoverer is the strongest thing this library allows
  # without a display or a main loop: the constructor builds a real
  # uridecodebin out of the plugin registry, so it exercises the GStreamer
  # initialisation the loader does in pre_load. Without gst_init it does not
  # fail here -- the *load* segfaults long before, which is why this suite
  # running at all is itself the assertion about pre_load.
  describe GstPbutils::Discoverer do
    let(:timeout) { 5 * 1_000_000_000 } # GStreamer clock time is nanoseconds.

    it "constructs, and is a GObject" do
      discoverer = GstPbutils::Discoverer.new(timeout)

      expect(discoverer).to be_a(GstPbutils::Discoverer)
      expect(discoverer).to be_a(GLib::Object)
    end

    it "round-trips the timeout it was constructed with as a GObject property" do
      discoverer = GstPbutils::Discoverer.new(timeout)

      expect(discoverer.timeout).to be == timeout

      discoverer.timeout = 2 * 1_000_000_000

      expect(discoverer.timeout).to be == 2 * 1_000_000_000
    end

    it "reports a URI it cannot read as a failure rather than crashing" do
      discoverer = GstPbutils::Discoverer.new(timeout)

      # A path that does not exist. The point is that this arrives in Ruby --
      # as an exception or as an info whose result is not OK -- and does not
      # take the process with it.
      begin
        info = discoverer.discover_uri("file:///nonexistent/#{Process.pid}.mp4")
        expect(info.result).not.to be == GstPbutils::DiscovererResult::OK
      rescue GLib::Error => error
        expect(error.message).to be_a(String)
      end
    end
  end
end
