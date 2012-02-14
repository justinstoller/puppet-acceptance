module Unix::Service
  include CommandFactory

  def service(name, action)
    if TestConfig.is_pe?
      name = case name
      when :agent
        self['platform'] =~ /debian|ubuntu/ ? 'pe-puppet-agent' : 'pe-puppet'
      when :master
        'pe-httpd'
      end
      execute("/etc/init.d/#{name} #{action}")
    end
  end
end
