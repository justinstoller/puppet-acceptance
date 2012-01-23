version  = options[:upgrade]
test_name "Install Puppet #{version}"
hosts.each do |host|
  platform = host['platform']

  host['os'] = case host.name
               when /cent/
                 'cent'
               when /rhel/
                 'rhel'
               when /debian/
                 'debian'
               when /ubuntu/
                 'ubuntu'
               when /sles/
                 'sles'
               when /sol/
                 'solaris'
               when /window/
                 'windows'
               end

  host['family'] = case host['platform']
                   when /debian|ubuntu/
                     'debian'
                   when /el/
                     'el'
                   when /sles/
                     'sles'
                   when /sol/
                     'solaris'
                   when /windows/
                     'windows'
                   end

  host['arch'] = case host['platform']
                 when /i386/
                   'i386'
                 when /amd64/
                   'amd64'
                 end

  package_name = nil
  base_name = nil
  if version =~ /^1\.[01]/
    base_name = "puppet-enterprise-#{version}-#{host['os']}-#{host['arch']}"
    package_name = base_name + '.tar'
  else
    if host['family'] == 'el'
      base_name="puppet-enterprise-#{version}-#{host['family']}-#{host['arch']}"
    else
      base_name = "puppet-enterprise-#{version}-#{host['os']}-#{host['arch']}"
    end
    if version =~ /^1\.2/
      package_name = base_name + '.tar'
    else
      package_name = base_name + '.tar.gz'
    end
  end

  local_dir = "/opt/enterprise/dists/pe#{version}/"
  remote_dir = "/tmp/"
  local_file = local_dir + package_name
  host['install_dir'] = remote_dir + base_name

  unless File.file? local_file
    Log.error "#{local_file} not found, help!"
    fail_test "Sorry, #{local_file} not found."
  end

  step "Pre Test Setup -- SCP install package to hosts"
  scp_to host, local_file, remote_dir

  step "Pre Test Setup -- Untar install package on hosts"
  on host, "cd #{remote_dir} && tar xf #{package_name}"

end

# Install Master first -- allows for auto cert signing
hosts.each do |host|
  next unless host.is_master?

  step "SCP Master Answer file to #{host}"
  scp_to host, "tmp/answers.#{host}.#{version}.install", host['install_dir']

  step "Install Puppet Master"
  on host, "cd #{host['install_dir']} && " +
    "./puppet-enterprise-installer -a answers.#{host}.#{version}.install"

end

# Install Puppet Agents
step "Install Puppet Agent"
hosts.each do |host|
  next if host.is_master?

  step "SCP Answer file to dist tar dir"
  scp_to host, "answers/answers.#{host}.#{version}.install", host['install_dir']

  step "Install Puppet Agent"
  on host, "cd #{host['install_dir']} && " +
    "./puppet-enterprise-installer -a answers.#{host}.#{version}.install"
end
