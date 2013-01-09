module PuppetAcceptance
  module Hosts
    module AIX
      module File

        def tmpfile(name)
          execute("rndnum=${RANDOM} && touch /tmp/#{name}.${rndnum} && echo /tmp/#{name}.${rndnum}")
        end

        def tmpdir(name)
          execute("rndnum=${RANDOM} && mkdir /tmp/#{name}.${rndnum} && echo /tmp/#{name}.${rndnum}")
        end

        def path_split(paths)
          paths.split(':')
        end

      end
    end
  end
end
