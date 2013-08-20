require 'open-uri'
require 'yaml'

module PuppetAcceptance
  module Config
    class FileParser

      def load_file( path )
        case path
        when /\.rb$/
          load_rb_file( path )
        when /\.ya?ml$/
          load_yaml_file( path )
        else
          load_flat_file( path )
        end
      end

      def load_rb_file( config_info = nil )
        with_common_guards_for config_info do
          return_as_properly_formatted do

            # It is important that the variable 'options_file_path' is
            # accessible, because puppetdb's options files rely on that variable
            options_file_path = config_info.dup

            result = eval( load_flat_file( config_info ) )
          end
        end
      end

      def load_yaml_file( config_info = nil )
        with_common_guards_for config_info do
          return_as_properly_formatted do

            content = load_flat_file( config_info )

            result  = YAML.load( content )
          end
        end
      end

      def load_flat_file( location )
        content = ''
        begin
          open( location ) do |file|
            while line = file.gets
              content << line
            end
          end
        rescue Errno::ENOTDIR, OpenURI::HTTPError

          raise "Could not find file at #{location}"
        end

        return content
      end

      def with_common_guards_for( config_info, &block )
        case config_info
        when NilClass
          return PuppetAcceptance::Config::Value.new
        when Hash
          return PuppetAcceptance::Config::Value.new( config_info )
        when PuppetAcceptance::Config::Value
          return config_info
        else
          return block.call
        end
      end

      def return_as_properly_formatted( &block )
        result = block.call
        if result.is_a? Hash
          return PuppetAcceptance::Config::Value.new( result )
        else
          return result
        end
      end

    end
  end
end
