begin
  require 'puppet_acceptance/dsl/wrappers'
rescue LoadError
  require File.expand_path(
    File.join(File.dirname(__FILE__), '..', 'dsl', 'wrappers'))
end

module PuppetAcceptance
  module Hosts
    class BasicHost
      include PuppetAcceptance::DSL::Wrappers

      # The logger this host will use for messages
      attr_accessor :logger

      # The connection the host will use, set by the factory
      # {Hosts::Abstraction}.
      attr_accessor :connection

      # The options this host will use
      attr_accessor :options

      # The Hosts "name" defaults to the key it's details live under in the
      # yaml config file...
      attr_reader :name

      # These are defaults specified by sub classes.
      attr_reader :defaults

      def initialize name, options, config
        @logger = options[:logger]
        @name, @options, @config = name, options.dup, config

        # This is annoying and its because of drift/lack of enforcement/lack
        # of having a explict relationship between our defaults, our setup
        # steps and how they're related through 'type' and the differences
        # between the assumption of our two configurations we have for many
        # of our products
        type = is_pe? ? :pe : :foss
        @defaults = merge_defaults_for_type @config, type
      end

      # @!visibility private
      def merge_defaults_for_type config, type
        base_defaults = self.class.send "#{type}_defaults".to_sym
        base_defaults.merge(config['CONFIG']).merge(config['HOSTS'][name])
      end

      # This is silliness to get a test to pass
      def self.pe_defaults
        { 'puppetpath' => '/etc/puppetlabs/puppet' }
      end

      def self.foss_defaults
        { 'puppetpath' => '/etc/puppet' }
      end

      def node_name
        # TODO: might want to consider caching here; not doing it for now
        # because I haven't thought through all of the possible scenarios
        # that could cause the value to change after it had been cached.
        result = exec puppet('agent', '--configprint node_name_value')
        result.stdout.chomp
      end

      # Retrieve any of the values assigned to this host
      #
      # @api public
      def []= k, v
        @defaults[k] = v
      end

      # Assign a value to this host
      #
      # @api public
      def [] k
        @defaults[k]
      end

      # @see #to_s
      def to_str
        @name
      end

      # Allows host to be interpolated in a string
      def to_s
        @name
      end

      # @deprecated
      def + other
        @name + other
      end

      # @!visibility private
      # This is a janky way to sort our FOSS vs Enterprise defaults
      def is_pe?
        @config.is_pe?
      end

      # @deprecated
      # See {PuppetAcceptance::Hosts::Abstraction} for building a
      # connection and assigning it to {#connection}
      def connect!
        @connection ||= SshConnection.connect( self['ip'] || @name,
                                               self['user'],
                                               self['ssh'] )
      end

      # Closes the connection
      def close
        connection.close if connection
      end

      # Runs a given [Command].
      def run command, opts = {}, &block
        # run_opts = options.merge( opts )
        # command_line = command_line_for( command )

        # logger should know if it's supposed to be silent...
        # or should be a null object....
        # logger.debug "\n#{name} $ #{cmdline}"
        # output_callback = logger.streaming_callback

        # Why did we get this far if we're doing a dryrun?
        # if run_opts[:dry_run]
        # # result = Result.new
        # else
        # # result = connection.execute(command_line, opts, output_callback)
        # # result.log( logger )

        # # Move this to {PuppetAcceptance::DSL::Helpers#on}
        # # unless result.exit_code_in?(options[:acceptable_exit_codes] || [0])
        # #   limit = 10
        # #   raise "Host '#{self}' exited with #{result.exit_code} " +
        # #    "running:\n #{cmdline}\nLast #{limit} lines of output " +
        # #    "were:\n#{result.formatted_output(limit)}"
        # # end
        # end

        # yield result if block_given?

        # result
      end

      def execute command, opts={}, &block
        if command.is_a? Command
          command_line = command.cmd_line(self)
        else
          command_line = Command.new(command).cmd_line(self)
        end

        if opts[:silent]
          output_callback = nil
        else
          logger.debug "\n#{self} $ #{cmdline}"
          output_callback = logger.method(:host_output)
        end

        unless $dry_run
          # is this returning a result object?
          # the options should come at the end of the method signature (rubyism)
          # and they shouldn't be ssh specific
          result = connection.execute(command_line, opts, output_callback)

          unless opts[:silent]
            # What?
            result.log(logger)
            # No, TestCase has the knowledge about whether its failed, checking acceptable
            # exit codes at the host level and then raising...
            # is it necessary to break execution??
            unless result.exit_code_in?(opts[:acceptable_exit_codes] || [0])
              limit = 10
              raise "Host '#{self}' exited with #{result.exit_code} running:\n #{cmdline}\nLast #{limit} lines of output were:\n#{result.formatted_output(limit)}"
            end
          end

          yield result if block_given?

          # Danger, so we have to return this result?
          result
        end
      end

      def do_scp_to source, target, opts
        logger.debug "localhost $ scp #{source} #{name}:#{target}"

        opts[:dry_run] = $dry_run

        result = connection.scp_to(source, target, opts)
        return result
      end

      def do_scp_from source, target, opts
        logger.debug "localhost $ scp #{name}:#{source} #{target}"

        opts[:dry_run] = $dry_run

        result = connection.scp_from(source, target, opts)
        return result
      end
    end
  end
end
