begin
  require 'puppet_acceptance/dsl/outcomes'
rescue LoadError
  require File.expand_path(
    File.join(File.dirname(__FILE__), '..', '..', 'dsl', 'outcomes'))
end

module PuppetAcceptance
  module Hosts
    module AIX
      module Group

        def group_list &block
          groups = []
          result = run( "lsgroup ALL" )

          result.stdout.each_line do |line|
            groups << (line.match(/^([^:]+)/) or next)[1]
          end

          yield result if block_given?

          groups
        end

        def group_get name, &block
          result = run( "lsgroup #{name}" )
          fail_test "failed to get group #{name}" unless
            result.stdout =~ /^#{name} id/

          yield result if block_given?

          result.stdout.chomp
        end

        def group_present name, &block
          result = run( "if ! lsgroup #{name}; then mkgroup #{name}; fi" )

          yield result if block_given?

          result.stdout.chomp
        end

        def group_absent name, &block
          result = run( "if lsgroup #{name}; then rmgroup #{name}; fi" )

          yield result if block_given?

          result.stdout.chomp
        end
      end
    end
  end
end
