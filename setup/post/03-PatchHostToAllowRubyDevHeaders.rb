hosts.each do |host|

  host['install_dir'] = "/tmp/puppet-enterprise-#{config['pe_ver']}-#{host['platform']}"

  def host.ensure_ruby_dev!
    unless @ruby_dev_installed
      if TestConfig.is_pe?
        dev_package = ''
        pre_reqs    = [ 'gcc' ]
        pre_reqs    << 'build_essential' if
          self['platform'] =~ /debian|ubuntu/

        execute("ls #{self['install_dir']}/packages/#{self['platform']}/ " +
          "| grep ruby.*dev") do |result|
            dev_package = result.stdout.chomp
        end

        dev_package = "#{self['install_dir']}/packages/#{self['platform']}/" +
          dev_package

        install dev_package
        @ruby_dev_installed = true
      else
        @ruby_dev_installed = true
      end
    end
  end
end
