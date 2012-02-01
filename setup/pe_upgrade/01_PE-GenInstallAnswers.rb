

test_name "Generate Puppet Enterprise answer files"

skip_test "Skipping answers file generation for non PE tests" unless
  options[:type] =~ /pe/

skip_test "Skipping answers file generation, --no-install selected" if
  options[:noinstall]

$certcmd = '`uname | grep -i sunos > /dev/null && hostname || hostname -s`'

version = options[:upgrade]
type = 'install'

hosts.each do |host|
  host['answers']  = AnswerFile.new
  host['answers'] << GlobalAnswers.new(version)
  host['answers'] << AgentAnswers.new(version)
  host['answers'] << DashboardAnswers.new(version) if host.is_dashboard?
  host['answers'] << MasterAnswers.new(version) if host.is_master?
  host['answers'] << UpgradeAnswers.new(version) if type == 'upgrade'
  host['answers'] << UninstallAnswers.new(version) if type == 'uninstall'
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

