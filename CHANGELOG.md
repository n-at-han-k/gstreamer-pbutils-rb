# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-11-03

### Added

- `GstPbutils`, defined from the `GstPbutils-1.0` GObject Introspection typelib at
  require time, giving the discoverer that inspects a media file, encoding profiles, and human-readable codec descriptions. `GstPbutils::Loader` is a
  `GObjectIntrospection::Loader` subclass, so the binding is the whole
  namespace rather than a hand-written subset, and it does not drift as the
  library gains API.
- A dev shell (`flake.nix`) that pins the library and glib from one nixpkgs and
  puts their typelibs on `GI_TYPELIB_PATH`, and CI that runs the suite inside
  it, because the environment is the hard part of an introspection binding.

### Changed

- The binding no longer goes through Rust. Earlier revisions wrapped a
  gir-generated crate with magnus, which meant an `ext/` directory, a Cargo
  workspace, system libraries at build time and a nine-platform cross-compile
  matrix, to expose the handful of functions someone had written by hand. The
  typelib loader replaces all of it with about twenty lines of Ruby.
- The gem is pure Ruby and declares no extensions. Installing it still
  compiles C, because `glib2` and `gobject-introspection` are native
  extensions built against glib — but this gem adds no build step of its own,
  and those two are what every ruby-gnome application already has via `gtk4`.
- `bin/release-gem` releases one gem. It was built for the Rust model, where a
  release meant a source gem plus one precompiled gem per platform downloaded
  from the Cross Compile workflow; that workflow is gone and there are no
  platform gems, so left alone it aborted before doing anything.

### Removed

- `ext/`, `Cargo.toml`, `Cargo.lock`, the cross-compile workflow, and the
  `rb_sys` and `rake-compiler` dependencies.
