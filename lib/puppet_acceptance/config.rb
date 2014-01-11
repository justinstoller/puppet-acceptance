require 'puppet_acceptance/config/value'
require 'puppet_acceptance/config/defaults'
require 'puppet_acceptance/config/cli_parser'
require 'puppet_acceptance/config/file_parser'
require 'puppet_acceptance/config/env_parser'
require 'puppet_acceptance/config/validator'
require 'puppet_acceptance/config/munger'
require 'puppet_acceptance/config/manager'

module PuppetAcceptance
  module Config
    def self.set &block
      PuppetAcceptance::Config::Value.new &block
    end
  end
end
