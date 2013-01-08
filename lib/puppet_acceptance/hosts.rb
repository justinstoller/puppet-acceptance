begin
  require "puppet_acceptance/hosts/abstraction"
rescue LoadError
  require File.expand_path(
    File.join(File.dirname(__FILE__),
              'hosts',
              'abstraction')
  )
end

module PuppetAcceptance
  module Hosts
    include PuppetAcceptance::Hosts::Abstraction

  end
end
