module PuppetAcceptance
  module Hosts
    module Unix
      module File
        include PuppetAcceptance::CommandFactory

        def tmpfile(name)
          execute("mktemp -t #{name}.XXXXXX")
        end

        def tmpdir(name)
          execute("mktemp -td #{name}.XXXXXX")
        end

        def path_split(paths)
          paths.split(':')
        end

      end
    end
  end
end
