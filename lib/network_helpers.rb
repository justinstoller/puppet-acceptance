#
# This module require that whatever it is mixed into provide a #hosts
# method that yields each node in the network to be acted on
#
# TODO: Currently mixes both general network/ssh-state-machine methods and
# Puppetlabs specific helpers
#
module NetworkHelpers
  require 'tempfile'
  require_relative 'log'
  require_relative 'command'

  #
  # Identify hosts
  #
  def agents
    hosts 'agent'
  end

  def master
    masters = hosts 'master'
    fail "There must be exactly one master" unless masters.length == 1
    masters.first
  end

  def dashboard
    dashboards = hosts 'dashboard'
    Log.warn "There is no dashboard host configured" if dashboards.empty?
    fail "Cannot have more than one dashboard host" if dashboards.length > 1
    dashboards.first
  end

  def database
    databases = hosts 'database'
    database.first
  end

  #
  # Basic operations
  #
  def host_command(command_string)
    HostCommand.new(command_string)
  end

  def on(host, command, options={}, &block)
    if host.respond_to? :each
      #  This works to parallelize the tests, but with unfortunate
      #  consequences for the rest of the harness
      #  threads = []
      #  host.each do |node|
      #    new_block = block_given? ? block.dup : Proc.new {|a,b,c| }
      #    threads << Thread.new(node, command, options) do |n,m,o|
      #      on n, m, o, &new_block
      #    end
      #  end
      #  threads.each {|t| t.join }
      host.each do |h|
        on h, command, options, &block
      end
    else
      options[:acceptable_exit_codes] ||= [0]
      options[:failing_exit_codes]    ||= [1]

      command = Command.new(command) if command.is_a? String
      result = host.exec(command.cmd_line(host), options)

      unless options[:silent]
        result.log
        unless options[:acceptable_exit_codes].include?(result.exit_code)
          Log.debug "Exit code is: #{result.exit_code}"
          fail "Host #{host} exited with #{result.exit_code}" +
                 " running: #{command.cmd_line('')}"
        end
      end

      # Also, let additional checking be performed by the caller.
      yield result.stdout, result.stderr, result.exit_code if block_given?

      return result
    end
  end

  def scp_to(host, from_path, to_path, options={})
    if host.respond_to? :each
      host.each { |h| scp_to h, from_path, to_path, options }
    else
      result = host.do_scp(from_path, to_path)
      result.log
      raise "scp exited with #{result.exit_code}" if result.exit_code != 0
    end
  end

  def apply_manifest_on(hosts, manifest, options={}, &block)
    on_options = {:stdin => manifest + "\n"}
    on_options[:acceptable_exit_codes] = options[:acceptable_exit_codes]
    args = ["--verbose"]
    args << "--parseonly" if options[:parseonly]
    on hosts, PuppetCommand.new(:apply, *args), on_options, &block
  end

  def run_script_on(host, script, &block)
    remote_path = File.join("", "tmp", File.basename(script))
    scp_to host, script, remote_path
    on host, remote_path, &block
  end

  def run_agent_on(host, arg='--no-daemonize --verbose --onetime --test', options={}, &block)
      on host, PuppetCommand.new(:agent, arg), options, &block
  end

  def run_cron_on(host, action, user, entry="", &block)
    platform = host['platform']
    if platform.include? 'solaris'
      case action
        when :list   then args = '-l'
        when :remove then args = '-r'
        when :add
          on host,
             "echo '#{entry}' > /var/spool/cron/crontabs/#{user}", &block
      end
    else         # default for GNU/Linux platforms
      case action
        when :list   then args = '-l -u'
        when :remove then args = '-r -u'
        when :add
           on host,
             "echo '#{entry}' > /tmp/#{user}.cron && crontab -u #{user} " +
             "/tmp/#{user}.cron", &block
      end
    end

    if args
      case action
        when :list, :remove then on host, "crontab #{args} #{user}", &block
      end
    end
  end

  def with_master_running_on(host, arg='--daemonize', &block)
    on hosts, host_command('rm -rf #{host["puppetpath"]}/ssl')
    agents.each do |agent|
      if vardir = agent['puppetvardir']
        on agent, "rm -rf #{vardir}/*"
      end
    end

    on host, PuppetCommand.new(:master, '--configprint pidfile')
    pidfile = stdout.chomp
    on host, PuppetCommand.new(:master, arg)
    poll_master_until(host, :start)
    master_started = true
    yield if block
  ensure
    if master_started
      on host, "kill $(cat #{pidfile})"
      poll_master_until(host, :stop)
    end
  end

  def poll_master_until(host, verb)
    timeout = 30
    verb_exit_codes = {:start => 0, :stop => 7}

    Log.debug "Wait for master to #{verb}"

    agent = agents.first
    wait_start = Time.now
    done = false

    until done or Time.now - wait_start > timeout
      on(agent, "curl -k https://#{master}:8140 >& /dev/null", :acceptable_exit_codes => (0..255))
      done = exit_code == verb_exit_codes[verb]
      sleep 1 unless done
    end

    wait_finish = Time.now
    elapsed = wait_finish - wait_start

    if done
      Log.debug "Slept for #{elapsed} seconds waiting for Puppet Master to #{verb}"
    else
      Log.error "Puppet Master failed to #{verb} after #{elapsed} seconds"
    end
  end

  def create_remote_file(hosts, file_path, file_content)
    Tempfile.open 'puppet-acceptance' do |tempfile|
      File.open(tempfile.path, 'w') { |file| file.puts file_content }

      scp_to hosts, tempfile.path, file_path
    end
  end

end
