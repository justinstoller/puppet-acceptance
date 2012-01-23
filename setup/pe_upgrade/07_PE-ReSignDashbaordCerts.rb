#
# This step sets up certificates for the case
# when the dashbaord is split up from the puppetmaster
#
monolithic = nil

hosts.each do |host|
  monolithic = true if host.is_master? and host.is_dashboard?
end

skip_test 'Only need to set up certs if we have a puppet master' and
  break unless master

skip_test 'Only need to set up multi-node certs if we have a dashboard' and
  break unless dashboard

skip_test 'Only need to set up multi-node certs if dashboard' +
  'and master are not installed on the same node' and
  break if monolithic

skip_test 'This test expects that the dashbaord has an agent installed' and
  break unless agents.include? dashboard

skip_test 'Certs only need signing in post 1.2 installs' and
  break if TestConfig.puppet_enterprise_version =~ /^1\.[01]/

test_name 'Sign certs when the dashboard and master are on seperate nodes.'

step 'set up dashboard certificates'
on dashboard, 'cd /opt/puppet/share/puppet-dashboard;' +
  '/opt/puppet/bin/rake --trace cert:request'

on master, puppet('cert --sign pe-internal-dashboard')

on dashboard, 'cd /opt/puppet/share/puppet-dashboard;' +
  '/opt/puppet/bin/rake --trace cert:retrieve'

step 'start puppet master and inventory service'
on dashboard, '/etc/init.d/pe-httpd start'
