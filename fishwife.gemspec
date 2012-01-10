# -*- ruby -*- encoding: utf-8 -*-

gem 'rjack-tarpit', '~> 2.0'
require 'rjack-tarpit/spec'

RJack::TarPit.specify do |s|
  require 'fishwife/base'

  s.version = Fishwife::VERSION
  s.summary = "A hard working Jetty 7 based rack handler."

  s.add_developer( 'David Kellum', 'dek-oss@gravitext.com' )

  s.depend 'rack',                  '~> 1.3.6'
  s.depend 'rjack-jetty',           '~> 7.5.0'
  s.depend 'rjack-slf4j',           '~> 1.6.1'

  s.depend 'rjack-logback',         '~> 1.2',       :dev
  s.depend 'rspec',                 '~> 2.8.0',     :dev

  s.platform = :java
end