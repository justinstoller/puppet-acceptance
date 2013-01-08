begin
  require 'puppet_acceptance/command_factory'
rescue LoadError
  require File.expand_path(
    File.join(File.dirname(__FILE__), '..', 'command_factory'))
end

begin
  require 'puppet_acceptance/hosts/basic_host'
rescue LoadError
  require File.expand_path(File.join(File.dirname(__FILE__), 'basic_host'))
end

module PuppetAcceptance
  module Hosts
    module Unix
      class Host < PuppetAcceptance::Hosts::BasicHost

        require File.expand_path(File.join(File.dirname(__FILE__), 'unix', 'user'))
        require File.expand_path(File.join(File.dirname(__FILE__), 'unix', 'group'))
        require File.expand_path(File.join(File.dirname(__FILE__), 'unix', 'exec'))
        require File.expand_path(File.join(File.dirname(__FILE__), 'unix', 'file'))

        include Unix::User
        include Unix::Group
        include Unix::File
        include Unix::Exec

        def self.pe_defaults
          {
          'user'          => 'root',
          'puppetpath'    => '/etc/puppetlabs/puppet',
          'puppetbin'     => '/opt/puppet/bin/puppet',
          'puppetbindir'  => '/opt/puppet/bin',
          'pathseparator' => ':',
          }
        end

        def self.foss_defaults
          {
            'user'              => 'root',
            'puppetpath'        => '/etc/puppet',
            'puppetvardir'      => '/var/lib/puppet',
            'puppetbin'         => '/usr/bin/puppet',
            'puppetbindir'      => '/usr/bin',
            'hieralibdir'       => '/opt/puppet-git-repos/hiera/lib',
            'hierapuppetlibdir' => '/opt/puppet-git-repos/hiera-puppet/lib',
            'hierabindir'       => '/opt/puppet-git-repos/hiera/bin',
            'pathseparator'     => ':',
          }
        end
      end
    end
  end
end
