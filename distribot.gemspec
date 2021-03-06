Gem::Specification.new do |spec|
  spec.name        = 'distribot'
  spec.version     = '0.1.12'
  spec.authors     = ['John Drago']
  spec.email       = 'jdrago.999@gmail.com'
  spec.homepage    = 'https://github.com/distribot/distribot'
  spec.summary     = 'Distributed flow engine'
  spec.description = 'Distributed flow engine based on redis and rabbitmq'
  spec.required_rubygems_version = '>= 1.3.6'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'shoulda-matchers'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'faker'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'rubocop'

  spec.add_dependency 'activesupport'
  spec.add_dependency 'bunny'
  spec.add_dependency 'redis'
  spec.add_dependency 'semantic'
  spec.add_dependency 'concurrent-ruby'
  spec.add_dependency 'logstash-logger'
end
