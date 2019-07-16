lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'global_update_command_writer_iii_doesnt_want_you_to_know_about/version'

Gem::Specification.new do |spec|
  spec.name          = 'global_update_command_writer_iii_doesnt_want_you_to_know_about'
  spec.version       = GlobalUpdateCommandWriterIIIDoesntWantYouToKnowAbout::VERSION
  spec.authors       = ['ldss-jm']
  spec.email         = ['ldss-jm@users.noreply.github.com']

  spec.summary       = 'Writes Sierra (III ILS) global update save files that will load custom-per-record data'
  spec.homepage      = 'https://github.com/ldss-jm/global-update-command-writer-iii-doesnt-want-you-to-know-about'

  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'marc', '~> 1.0'
end
