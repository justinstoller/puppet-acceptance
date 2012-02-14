require 'lib/host'
require 'lib/command_factory'

module Unix
  class Host < Host
    require 'lib/host/unix/user'
    require 'lib/host/unix/group'
    require 'lib/host/unix/file'
    require 'lib/host/unix/exec'
    require 'lib/host/unix/package'
    require 'lib/host/unix/service'
    require 'lib/host/unix/utilities'

    include Unix::User
    include Unix::Group
    include Unix::File
    include Unix::Exec
    include Unix::Package
    include Unix::Service
    include Unix::Utilities

    PE_DEFAULTS = {
      'user'         => 'root',
      'puppetpath'   => '/etc/puppetlabs/puppet',
      'puppetbin'    => '/usr/local/bin/puppet',
      'puppetbindir' => '/opt/puppet/bin'
    }

    DEFAULTS = {
      'user'         => 'root',
      'puppetpath'   => '/etc/puppet',
      'puppetvardir' => '/var/lib/puppet',
      'puppetbin'    => '/usr/bin/puppet',
      'puppetbindir' => '/usr/bin'
    }

    def initialize(name, overrides, defaults)
      super(name, overrides, defaults)

      @defaults = defaults.merge(TestConfig.is_pe? ? PE_DEFAULTS : DEFAULTS)
    end
  end
end
