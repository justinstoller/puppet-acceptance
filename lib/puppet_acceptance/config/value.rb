module PuppetAcceptance
  module Config
    class Value
      attr_accessor :defaults

      def initialize( defaults = Hash.new, &block )
        @defaults = defaults
        yield self if block_given?
      end

      def []( key )
        fetch( key, self.class.new )
      end

      def to_ary
        defaults.to_a
      end
      alias_method :to_a, :to_ary

      def fetch( key, default_value, &block )
        raw_value = defaults[key.to_sym]
        raw_value ||= defaults[key.to_s]
        if block_given?
          raw_value ||= block.call( key )
        else
          raw_value ||= default_value
        end

        if raw_value.is_a? Hash
          value = self.class.new( raw_value )
        else
          value = raw_value
        end

        set( key, value ) unless exists?( key )

        return value
      end

      def exists?( key )
        defaults.has_key?( key.to_s ) or defaults.has_key?( key.to_sym )
      end

      def []=( key, value )
        set( key, value )
      end

      def set( key, value )
        defaults[key.to_sym] = value
      end

      def to_hash
        @defaults
      end

      def finalize!
        final = {}
        defaults.each_pair do |key, value|
          if value.is_a? self.class
            final[key] = value.finalize!
          else
            final[key] = value
          end
        end

        return final
      end

      def method_missing( meth, *values, &block )
        key = meth.to_s.end_with?( '=' ) ? meth.to_s.chop.to_sym : meth
        if values.empty? and not block_given?
          return self[key]

        elsif values.empty? and block_given?
          if block.arity == 1
            block.call( self[key] )

          else
            set( key, block )
          end

        elsif values.length == 1
          set( key, values.first )

        else
          set( key, values )
        end
      end

      def merge( other_conf )
        if other_conf.is_a? self.class
          values = other_conf.defaults
        elsif other_conf.is_a? Hash
          values = other_conf
        else
          raise "Don't know how to merge #{other_conf.class}: #{other_conf.inspect}"
        end
        self.class.new( defaults.merge( values ) )
      end
    end
  end
end
