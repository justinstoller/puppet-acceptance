# We raise here instead of call `raise_and_report` because we don't have a
# logger here and we expect to be called without one, we shoud maybe have
# real Exceptions here too??
module PuppetAcceptance
  module Config
    class Validator
      def validate( args )

        validate_type( args[:type] )

        validate_fail_mode( args[:fail_mode] )

        validate_config( args[:config] )

        validate_options_file( args[:options] )
      end

      def validate_type( type )
        if type && type !~ /(pe)|(git)/
          raise ArgumentError.new(
            "--type must be one of pe or git, not '#{type}'" )
        end
      end

      def validate_fail_mode( fail_mode )
        unless ["fast", "stop", nil].include?( fail_mode )
          raise ArgumentError.new( "--fail-mode must be one of fast, stop" )
        end
      end

      def validate_config( config )
        unless config
          raise ArgumentError.new(
            "We require a Host Configuration file\n" +
            "Please specify one with `-c`, `--config` on the command line\n" +
            "or with the :config attribute in an options file" )
        end
      end

      def validate_options_file( options_file )
        unless options_file
          unless File.exists?( File.expand_path( options_file ) )
            raise ArgumentError.new(
              "Specified options file '#{options_file}' does not exist!" )
          end
        end
      end

    end
  end
end
