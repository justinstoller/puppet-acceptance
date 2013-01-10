module PuppetAcceptance
  module Hosts
    module Unix
      module File

        def tmpfile name
          run("mktemp -t #{name}.XXXXXX").stdout.chomp
        end

        def tmpdir name
          run("mktemp -td #{name}.XXXXXX").stdout.chomp
        end

        def path_split paths
          paths.split(':')
        end

      end
    end
  end
end
