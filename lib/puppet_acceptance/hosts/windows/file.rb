module PuppetAcceptance
  module Hosts
    module Windows
      module File

        def tmpfile(name)
          execute("cygpath -m $(mktemp -t #{name}.XXXXXX)")
        end

        def tmpdir(name)
          execute("cygpath -m $(mktemp -td #{name}.XXXXXX)")
        end

        def path_split(paths)
          paths.split(';')
        end
      end
    end
  end
end
