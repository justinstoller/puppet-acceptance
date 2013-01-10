begin
  require 'puppet_acceptance/dsl/outcomes'
rescue LoadError
  require File.expand_path(
    File.join(File.dirname(__FILE__), '..', '..', 'dsl', 'outcomes'))
end

module PuppetAcceptance
  module Hosts
    module Unix
      module User

        def user_list &block
          users = []
          result = run("getent passwd")

          result.stdout.each_line do |line|
            users << (line.match( /^([^:]+)/) or next)[1]
          end

          yield result if block_given?

          users
        end

        def user_get name, &block
          result = run("getent passwd #{name}")

          fail_test "failed to get user #{name}" unless
            result.stdout =~  /^#{name}:/

          yield result if block_given?

          result.stdout.chomp
        end

        def user_present name, &block
          result = run( "if ! getent passwd #{name}; then useradd #{name}; fi")

          yield result if block_given?

          result.stdout.chomp
        end

        def user_absent name, &block
          result = run( "if getent passwd #{name}; then userdel #{name}; fi" )

          yield result if block_given?

          result.stdout.chomp
        end
      end
    end
  end
end
