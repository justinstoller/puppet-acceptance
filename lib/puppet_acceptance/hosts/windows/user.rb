begin
  require 'puppet_acceptance/dsl/outcomes'
rescue LoadError
  require File.expand_path(
    File.join(File.dirname(__FILE__), '..', '..', 'dsl', 'outcomes'))
end

module PuppetAcceptance
  module Hosts
    module Windows
      module User

        def user_list &block
          users = []
          result = run( 'cmd /c echo "" | ' +
                        'wmic useraccount where localaccount="true" ' +
                        'get name /format:value' )

          result.stdout.each_line do |line|
            users << (line.match(/^Name=([\w ]+)/) or next)[1]
          end

          yield result if block_given?

          users
        end

        def user_get name, &block
          result = run("net user \"#{name}\"")

          fail_test "failed to get user #{name}" unless
            result.stdout =~ /^User name\s+#{name}/

          yield result if block_given?

          result.stdout.chomp
        end

        def user_present name, &block
          result = run( "net user /add \"#{name}\"",
                         {:acceptable_exit_codes => [0,2]} )

          yield result if block_given?

          result.stdout.chomp
        end

        def user_absent name, &block
          result = run("net user /delete \"#{name}\"",
                        {:acceptable_exit_codes => [0,2]} )

          yield result if block_given?

          result.stdout.chomp
        end
      end
    end
  end
end
