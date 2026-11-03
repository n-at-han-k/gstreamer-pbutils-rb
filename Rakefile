# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

# There is no compile task. The binding is GObjectIntrospection::Loader
# reading GstPbutils-1.0.typelib at require time, so this gem has no extension, no Cargo
# workspace and no per-platform build.

task :test do
  sh "bin/test"
end

task default: :test
