

test_name "Generate Puppet Enterprise answer files"

skip_test "Skipping answers file generation for non PE tests" unless
  options[:type] =~ /pe/

skip_test "Skipping answers file generation, --no-install selected" if
  options[:noinstall]

$certcmd = '`uname | grep -i sunos > /dev/null && hostname || hostname -s`'

version = config['pe_ver']
type = 'install'

hosts.each do |host|
  host['answers']  = AnswerFile.new(@network, host, version)
  host['answers'] << GlobalAnswers
  host['answers'] << AgentAnswers
  host['answers'] << DashboardAnswers if host.is_dashboard?
  host['answers'] << MasterAnswers if host.is_master?
  host['answers'] << UpgradeAnswers if type == 'upgrade'
  host['answers'] << UninstallAnswers if type == 'uninstall'
end

hosts.each do |host|
  FileUtils.rm "tmp/answers.#{host}.#{version}.#{type}" if
    File.exists? "tmp/answers.#{host}.#{version}.#{type}"
end

hosts.each do |host|
  File.open "tmp/answers.#{host}.#{version}.#{type}", 'w' do |file|
    file.puts host['answers']
  end
end

