begin
  require 'puppet_acceptance/dsl/outcomes'
rescue LoadError
  require File.expand_path(
    File.join(File.dirname(__FILE__), '..', '..', 'dsl', 'outcomes'))
end

module PuppetAcceptance
  module Hosts
    module Windows
      module Group

        def group_list &block
          groups = []

          result = run( 'cmd /c echo "" | ' +
                   'wmic group where localaccount="true" ' +
                   'get name /format:value' )

          result.stdout.each_line do |line|
            groups << (line.match(/^Name=([\w ]+)/) or next)[1]
          end

          yield result if block_given?

          groups
        end

        def group_get name, &block
          result = run("net localgroup \"#{name}\"")

          fail_test "failed to get group #{name}" unless
            result.stdout =~ /^Alias name\s+#{name}/

          yield result if block_given?

          res.stdout.chomp
        end

        def group_present name, &block
          result = run( "net localgroup /add \"#{name}\"",
                        {:acceptable_exit_codes => [0,2]} )

          yield result if block_given?

          result.stdout.chomp
        end

        def group_absent name, &block
          result = run( "net localgroup /delete \"#{name}\"",
                        {:acceptable_exit_codes => [0,2]} )

          yield result if block_given?

          result.stdout.chomp
        end
      end
    end
  end
end
