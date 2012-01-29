step 'PE: Puppet Master Sign all Requested Agent Certs'
hosts.each do |host|
  next if host.is_master?

  on master, puppet("cert --sign #{host}") do |stdout, stderr, exit_code|
    assert_no_match(/Could not call sign/, stdout,
                    "Unable to sign cert for #{host}")
  end
end
