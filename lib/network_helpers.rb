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
    masters.first
  end

  def dashboard
    dashboards = hosts 'dashboard'
    dashboards.first
  end

  def database
    databases = hosts 'database'
    databases.first
  end

  #
  # Basic operations
  #
  def host_command(command_string)
    HostCommand.new(command_string)
  end

  def on(host, command, options={}, &block)
    command = Command.new(command) if command.is_a? String
    host.do_action 'RemoteExec', command
    host.set_callbacks_for command, options
    host.ssh.loop
  end

  def reset_streams_for(hosts)
    if hosts.respond_to? :each
      hosts.each do |host|
        host.reset_streams
      end
    else
      hosts.reset_streams
    end
  end

  def concurrently_on(hosts, command, options, &block)
    connections = Array.new(hosts)
    connections.each do |host|
      host.do_action 'RemoteExec', command
      host.set_callbacks_for command, options
    end
    condition = Proc.new {|s| s.busy? }
    loop do
      connections.delete_if {|host| !host.ssh.process(0.1, &condition) }
      break if connections.empty?
    end
  end

  def scp_to(host, from_path, to_path, options={})
    if host.respond_to? :each
      host.each { |h| scp_to h, from_path, to_path, options }
    else
      options[:acceptable_exit_codes] ||= [0]
      options[:failing_exit_codes]    ||= [1]

      msg = "Scp from #{from_path} to #{to_path}"
      host.do_scp(from_path, to_path)
      sanity_check_test(host, msg, options)

      host.reset_streams
    end
  end
end
