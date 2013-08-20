module PuppetAcceptance
  module Config
    class EnvParser

      PREFIX = 'HARNESS'
      DELIMITER = '__'

      attr_reader :prefix, :delimiter

      def initialize( env = ENV.dup, prefix = PREFIX, delimiter = DELIMITER )
        @env       = env
        @prefix    = prefix
        @delimiter = delimiter
      end

      # Should find possible harness values and return a configuration
      # object that includes them
      def parse
        hash = {}
        env.each_pair do |key, value|
          if key =~ /^#{prefix}#{delimiter}$/
            levels = key.split( delimiter )
            levels.shift
            levels = levels.map {|l| l.downcase.to_sym }
            accumulator = hash
            levels.length.times do |level|
              if level == ( levels.length - 1 )
                accumulator[levels[level]] = value
              else
                accumulator[levels[level]] ||= {}
                acuumulator = accumulator[levels[level]]
              end
            end
          end
        end

        PuppetAcceptance::Config::Value.new( hash )
      end
    end
  end
end
