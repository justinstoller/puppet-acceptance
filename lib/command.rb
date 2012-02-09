# An immutable data structure representing a task to run on a remote
# machine.
class Command
  def initialize(command_string)
    @command_string = command_string
  end

  def cmd_line(host)
    @command_string
  end

  def to_s
    cmd_line('')
  end

  def puppet_env_command(host)
    rubylib = [
      host['pluginlibpath'],
      host['puppetlibdir'],
      host['facterlibdir'],
      '$RUBYLIB'
    ].compact.join(':')

    path    = [
      host['puppetbindir'],
      host['facterbindir'],
      '$PATH'
    ].compact.join(':')

    cmd     = host['platform'] =~ /windows/ ? 'cmd.exe /c' : ''

    %Q{env RUBYLIB="#{rubylib}" PATH="#{path}" #{cmd}}
  end
end

class PuppetCommand < Command
  def initialize(sub_command, *args)
    @sub_command = sub_command
    options = args.last.is_a?(Hash) ? args.pop : {}
    @options = options.map { |key, value| "--#{key}=#{value}" }
    @args = args
  end

  def cmd_line(host)
    puppet_path = host[:puppetbinpath] || "/bin/puppet" # TODO: is this right?

    args_string = (@args + @options).join(' ')
    "#{puppet_env_command(host)} puppet #{@sub_command} #{args_string}\n"
  end
end

class FacterCommand < Command
  def initialize(*args)
    @args = args
  end

  def cmd_line(host)
    args_string = @args.join(' ')
    "#{puppet_env_command(host)} facter #{args_string}"
  end
end

class HostCommand < Command
  def cmd_line(host)
    eval "\"#{@command_string}\""
  end
end
