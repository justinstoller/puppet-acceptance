require 'pp'

module PuppetAcceptance
  module Config
    class Manager

      SORT_ORDER = [ :defaults, :other, :file, :env, :cli ]

      attr_reader :input_types, :munger, :validator, :cli_parser, :env_parser, :file_parser

      def initialize( input_types = [ :cli, :env, :options_file, :hosts_config, :fog, :pe_version ],
                      validator   = Validator.new,
                      munger      = Munger.new,
                      cli_parser  = CliParser.new,
                      file_parser = FileParser.new,
                      env_parser  = EnvParser.new
                    )

        @input_types = input_types
        @validator   = validator
        @munger      = munger
        @cli_parser  = cli_parser
        @file_parser = file_parser
        @env_parser  = env_parser
      end

      def configuration_for( type, configuration_up_to_now )
        method_name = "parse_#{type}".to_sym

        puts ''
        puts 'configuration up to now:'
        puts configuration_up_to_now.inspect
        puts ''

        parsed_input  = self.send( method_name, configuration_up_to_now )

        puts 'parsed input:'
        puts parsed_input.inspect
        puts ''

        valid_input   = validator.validate( parsed_input )

        puts 'valid input:'
        puts valid_input.inspect
        puts ''

        configuration = munger.munge( valid_input )

        puts 'munged output:'
        puts configuration.inspect
        puts ''

        return configuration
      end

      def get_configuration
        defaults = PuppetAcceptance::Config::NEW_DEFAULTS
        configurations = []

        input_types.inject( [defaults] ) do |previous_configurations, input_type|

          #puts ''
          #puts input_type
          #puts 'previous configuration for this round: '
          #puts Array(previous_configurations).map{|c| c.inspect }
          #puts ''

          the_world_up_to_now = merge( *previous_configurations )
          this_configuration  = configuration_for( input_type, the_world_up_to_now )

          #puts ''
          #puts 'this computed configuration:'
          #puts this_configuration.inspect
          #puts ''

          configurations << this_configuration

          previous_configurations + [this_configuration]
        end

        merged_configuration = merge( *configurations )
        final_configuration = finalize( merged_configuration )

        return final_configuration
      end

      def parse_cli( configuration )
        cli_parser.parse
      end

      def parse_options_file( configuration )
        locations = Array( configuration[:options_file] )

        locations.each do |location|
          parsed_file_args = file_parser.load_file( location )

          break unless parsed_file_args
        end

        parsed_file_args
      end

      def parse_hosts_config( configuration )
        host_config = file_parser.load_file( configuration[:config] )
      end

      def parse_env( configuration )
        env_parser.parse
      end

      def parse_fog( configuration )
      end

      def merge( *args )
        return args.first if args.length == 1

        sorted = sort_inputs_by( args, SORT_ORDER )

        return multi_merge( *sorted )
      end

     private

      def sort_inputs_by( inputs, ordering )
        return inputs.sort do |input_a, input_b|
          ordering.index( input_a.type ) <=> ordering.index( input_b.type )
        end
      end

      def multi_merge( *args )
        return args.inject do |combined, new|
          combined.merge( new )
        end
      end

    end
  end
end
