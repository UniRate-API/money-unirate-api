# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

task default: %i[spec rubocop]

# The release runs in CI via rubygems/release-gem@v1, triggered by the pushed
# `v*` tag. Bundler's stock `release` task would *also* try to create and push
# the git tag and push the branch — both fail on a tag-triggered run (the tag
# already exists and the checkout is a detached HEAD). Override it to be
# git-free: build into pkg/ and push to RubyGems only. `gem push` still picks
# up the action's sigstore-attestation RUBYOPT patch, and the pkg/*.gem it
# leaves behind is what the action's await step polls for.
Rake::Task["release"].clear
desc "Build the gem into pkg/ and push it to RubyGems (no git operations)"
task release: %w[build] do
  gem_file = Dir["pkg/*.gem"].max_by { |f| File.mtime(f) }
  raise "No built gem found in pkg/" unless gem_file

  sh "gem push #{gem_file}"
end
