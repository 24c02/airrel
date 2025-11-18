# frozen_string_literal: true

require_relative "lib/airrel/version"

Gem::Specification.new do |spec|
  spec.name = "airrel"
  spec.version = Airrel::VERSION
  spec.authors = ["24c02"]
  spec.email = ["163450896+24c02@users.noreply.github.com"]

  spec.summary = "arel-like relational algebra for airtable"
  spec.description = "chainable query interface for airtable formulas. it's like arel but AIR. get it?"
  spec.homepage = "https://github.com/24c02/airrel"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/24c02/airrel"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "norairrecord", ">= 0.1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
