# -*- ruby -*- encoding: utf-8 -*-

gem 'rjack-tarpit', '~> 2.1'
require 'rjack-tarpit/spec'

RJack::TarPit.specify do |s|
  require 'fishwife/base'

  s.version = Fishwife::VERSION
  s.summary = "A Jetty based Rack HTTP 1.1 server."

  s.add_developer( 'David Kellum', 'dek-oss@gravitext.com' )

  s.depend 'rack',                  '>= 1.5.2', '< 1.7'
  s.depend 'rjack-jetty',           '>= 9.1.3', '< 9.3'
  s.depend 'rjack-slf4j',           '~> 1.7.2'

  s.depend 'json',                  '~> 1.8.2',     :dev
  s.depend 'rjack-logback',         '~> 1.5',       :dev
  s.depend 'rspec',                 '~> 2.13.0',     :dev

  s.maven_strategy = :no_assembly
end
