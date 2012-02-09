class TestCase
  class Host
    require 'rubygems'
    require 'net/ssh'
    require 'net/scp'
    require_relative '../result'

    attr_reader :name, :overrides
    attr_accessor :stdout, :stderr, :exit_code

    def self.create(name, overrides, defaults)
      case overrides['platform']
      when /windows/;
        WindowsHost.new(name, overrides, defaults)
      else
        UnixHost.new(name, overrides, defaults)
      end
    end

    # A cache for active SSH connections to our execution nodes.
    def initialize(name, overrides, defaults)
      @name, @overrides, @defaults = name, overrides, defaults
      @stderr = @stdout = ''
      @exit_code = nil
    end

    def []=(k,v)
      @overrides[k] = v
    end

    def [](k)
      @overrides.has_key?(k) ? @overrides[k] : @defaults[k]
    end

    def to_str
      @name
    end

    def to_s
      @name
    end

    def +(other)
      @name + other
    end

    def is_dashboard?
      self['roles'].include?('dashboard')
    end

    def is_master?
      self['roles'].include?('master')
    end

    def is_database?
      self['roles'].include?('database')
    end

    # Wrap up the SSH connection process; this will cache the connection and
    # allow us to reuse it for each operation without needing to reauth every
    # single time.
    def ssh
      tries = 1
      @ssh ||= begin
          Net::SSH.start(self, self['user'] || "root", self['ssh'])
        rescue Errno::ECONNREFUSED
          if tries < 4
            sec = 80 - (20 * tries)
            Log.warn "#{$!} (#{$!.class})"
            Log.warn "Try #{tries} -- Assuming Host Will Be Up Within #{sec} Seconds"
            Log.warn 'Trying again in 20 seconds'
            sleep 20
            tries += 1
            retry
          else
            Log.error "Failed to establish a connection to #{self}"
          end
        end
    end

    def close
      @ssh && @ssh.close
    end

    def do_action(verb,*args)
      Log.debug "#{self}: #{verb}(#{args.inspect})"
    end

    def exec(command, options)
      do_action 'RemoteExec', command
      set_callbacks_for command, options
      ssh.loop
    end

    def set_callbacks_for(command, options)
      ssh.open_channel do |channel|
        request_pty_for(channel) if options[:pty]
        execute_on(channel, command, options[:stdin])
      end
    end

    def execute_on(channel, command, stdin)
      channel.exec command do |ch, success|
        abort "FAILED: to execute command on a new channel on #{@name}" unless success
        set_stdout_from ch
        set_stderr_from ch
        set_exit_code_from ch

        eof_stdin_for ch, stdin if stdin
      end
    end

    def reset_streams
      @stderr = @stdout = ''
    end

    def request_pty_for(channel)
      channel.request_pty do |ch, success|
        if success
          puts "Allocated a PTY on #{@name}"
        else
          abort "FAILED: could not allocate a pty when requested on #{@name}}"
        end
      end
    end

    def eof_stdin_for(channel, stdin)
      channel.send_data stdin
      channel.process
      channel.eof!
    end

    def set_stdout_from(channel)
      channel.on_data do |ch, data|
        @stdout << data
      end
    end

    def set_stderr_from(channel)
      channel.on_extended_data do |ch, type, data|
        @stderr << data if type == 1
      end
    end

    def set_exit_code_from(channel)
      channel.on_request "exit-status" do |ch, data|
        @exit_code = data.read_long
      end
    end

    def do_scp(source, target)
      do_action('ScpFile', source, target)
      @stderr = ''
      @exit_code = 0
      recurse = File.directory?(source) ? true : false
      output_format = scp_output
      ssh.scp.upload!(source, target, :recursive => recurse, &output_format)
    end

    def scp_output
      @scp_output ||= Proc.new do |ch, name, sent, total|
        @stdout << "#{@name}: #{name}  #{sent}/#{total}\n"
      end
    end

  end

  class UnixHost < Host
    PE_DEFAULTS = {
      'puppetpath'   => '/etc/puppetlabs/puppet',
      'puppetbin'    => '/usr/local/bin/puppet',
      'puppetbindir' => '/opt/puppet/bin'
    }

    DEFAULTS = {
      'puppetpath'   => '/etc/puppet',
      'puppetvardir' => '/var/lib/puppet',
      'puppetbin'    => '/usr/bin/puppet',
      'puppetbindir' => '/usr/bin'
    }

    def initialize(name, overrides, defaults)
      super(name, overrides, defaults)

      @defaults = defaults.merge(TestConfig.is_pe? ? PE_DEFAULTS : DEFAULTS)
    end
  end

  class WindowsHost < Host
    DEFAULTS = {
      'user'         => 'Administrator',
      'puppetpath'   => '"`cygpath -F 35`/PuppetLabs/puppet/etc"',
      'puppetvardir' => '"`cygpath -F 35`/PuppetLabs/puppet/var"'
    }

    def initialize(name, overrides, defaults)
      super(name, overrides, defaults)

      @defaults = defaults.merge(DEFAULTS)
    end
  end
end
