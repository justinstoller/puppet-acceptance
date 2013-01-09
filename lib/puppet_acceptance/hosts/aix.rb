begin
  require 'puppet_acceptance/hosts/unix'
rescue LoadError
  require File.expand_path(File.join(File.dirname(__FILE__), 'unix'))
end

module PuppetAcceptance
  module Hosts
    module AIX
      class Host < PuppetAcceptance::Hosts::Unix::Host
        require File.expand_path(File.join(File.dirname(__FILE__), 'aix', 'user'))
        require File.expand_path(File.join(File.dirname(__FILE__), 'aix', 'group'))
        require File.expand_path(File.join(File.dirname(__FILE__), 'aix', 'file'))

        include AIX::User
        include AIX::Group
        include AIX::File

      end
    end
  end
end
