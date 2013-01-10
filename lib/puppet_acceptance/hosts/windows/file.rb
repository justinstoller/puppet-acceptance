module PuppetAcceptance
  module Hosts
    module Windows
      module File

        def tmpfile name
          run("cygpath -m $(mktemp -t #{name}.XXXXXX)").stdout.chomp
        end

        def tmpdir name
          run("cygpath -m $(mktemp -td #{name}.XXXXXX)").stdout.chomp
        end

        def path_split paths
          paths.split(';')
        end
      end
    end
  end
end
