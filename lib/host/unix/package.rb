module Unix::Package
  include CommandFactory

  def install(*args)
    if args.length == 1 && args[0] =~ /[\/\\]/
      # if we are given a single, absolute path to install
      # use low level tools
      if self['platform'] =~ /debian|ubuntu/
        install_cmd = "dpkg -i"
      else
        install_cmd = "rpm -i"
      end
    else
      case self['platform']
      when /debian|ubuntu/
        install_cmd = "apt-get install -y"
      when /el/
        install_cmd = "yum install -y"
      when /sles/
        install_cmd = "zypper install -y"
      end
    end

    execute("#{install_cmd} #{args.join(' ')}")
  end

  def gem(arg)
    gem_cmd = if TestConfig.is_pe?
                "#{self['puppetbindir']}/gem #{arg} --no-ri --no-rdoc"
              else
                "gem #{arg} --no-ri --no-rdoc"
              end

    execute(gem_cmd)
  end
end
