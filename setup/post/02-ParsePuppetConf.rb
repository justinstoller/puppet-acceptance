test_name "parse the Puppet Conf and save its values in a host var"

hosts.each do |host|

  step 'save puppet.conf'
  host['original_puppet_conf'] = ''
  on host, puppet("--configprint config") do
    host['puppet_conf_path'] = stdout.chomp
  end

  puppet_conf = {}
  puppet_conf['main'] ||= {}
  puppet_conf['master'] ||= {}
  puppet_conf['agent'] ||= {}

  def puppet_conf.out
    out = ''
    self.each_pair do |heading,values|
      out += "[#{heading}]\n"
      values.each_pair do |k,v|
        out += "  #{k} = #{v}\n"
      end
    end
    out
  end

  host['puppet_conf'] = puppet_conf

  on host, "cat #{host['puppet_conf_path']}" do
    host['original_puppet_conf'] = stdout.chomp

    key ||= ''
    stdout.each_line do |line|
      # skip comments and blank lines
      next if line =~ /\s*#/
      next if line =~ /^[\n\s]$/

      # save the conf section as a key in conf_file
      if line =~ /\[(.*)\]/
        key = $1.downcase
        host['puppet_conf'][key] ||= {}
        next
      end

      k, v = line.strip.split(/\s*=\s*/)
      host['puppet_conf'][key][k] = v
    end
  end
end
