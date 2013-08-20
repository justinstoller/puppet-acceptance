module PuppetAcceptance
  module Config
    class Manager
      GITREPO = 'git://github.com/puppetlabs'

      attr_reader :file_parser, :cli_parser, :validator

      def initialize( file_parser = PuppetAcceptance::Config::FileParser.new,
                      cli_parser  = PuppetAcceptance::Config::CliParser.new,
                      validator   = PuppetAcceptance::Config::Validator.new   )

        @file_parser = file_parser
        @cli_parser  = cli_parser
        @validator   = validator
      end

      def get_configuration( cli_args )

        parsed_cli_args = cli_parser.parse( arguments )

        if parsed_cli_args.exists?( :options_file )
          locations = Array( parsed_cli_args[:options_file] )
        else
          locations = PuppetAcceptance::Config::DEFAULTS[:options_file]
        end

        args_location    = locations.find {|loc| File.exists?( File.expand_path( loc )) }
        parsed_file_args = file_parser.load_rb_file( args_location )

        munged_cli_args  = munge_args( parsed_cli_args  )
        munged_file_args = munge_args( parsed_file_args )

        merged_args = merge_args( PuppetAcceptance::Config::DEFAULTS,
                                  munged_file_args,
                                  munged_cli_args                     )

        if merged_args[:print_help] or ( arguments.empty? && parsed_file_args.empty? )
          puts cli_args_parser
          exit # We should have a real way to say we want to terminate the program....
        end

        merged_args[:is_pe] = decide_if_pe( merged_args )

        validator.validate( merged_args )

        finalized_args = merged_args.finalize!

        files_config = file_parser.load_yaml_file( finalized_config[:config] )

        network_conf = set_hosts_config_defaults( files_config, finalized_config[:is_pe] )

        finalized_args[:network] = network_conf

        return finalized_args
      end

      def puppet_enterprise_dir
        @pe_dir ||= ENV['pe_dist_dir'] || '/opt/enterprise/dists'
      end

      def puppet_enterprise_version( type = :default )
        @pe_ver ||= load_pe_version( type )
      end

      def load_pe_version( type )
        default_file = type == :windows ? 'LATEST-win' : 'LATEST'
        dist_dir = puppet_enterprise_dir
        version_file = ENV['pe_version_file'] || default_file
        file_parser.load_flat_file( dist_dir + '/' + version_file )
      end

      def merge_args( defaults, args_from_file, args_from_cli )
        user_supplied_args = args_from_file.merge( args_from_cli )
        options = defaults.merge( user_supplied_args )

        return options
      end

      def pretty_print_args( args )
        pretty = [ "Options" ] +
          pretty_print_hash( args, "\t" )

        return pretty.compact.join( "\n" )
      end

      def pretty_print_hash( args, offset )
        args.map do |arg, val|
          if val and val != []
            [ "#{offset}#{arg.to_s}:" ] +
            if val.kind_of?( Array )
              val.map do |v|
                [ "#{offset}\t#{v.to_s}" ]
              end
            elsif val.kind_of?( Hash )
              pretty_print_hash( val, offset + offset )
            else
              [ "#{offset}\t#{val.to_s}" ]
            end
          end
        end.flatten
      end
    end
  end
end
