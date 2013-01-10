module PuppetAcceptance
  module Hosts
    module AIX
      module File

        def tmpfile name
          run( "rndnum=${RANDOM} && " +
                   "touch /tmp/#{name}.${rndnum} && " +
                   "echo /tmp/#{name}.${rndnum}" ).stdout.chomp
        end

        def tmpdir name
          run( "rndnum=${RANDOM} && " +
                   "mkdir /tmp/#{name}.${rndnum} && " +
                   "echo /tmp/#{name}.${rndnum}" ).stdout.chomp
        end

        def path_split paths
          paths.split(':')
        end

      end
    end
  end
end
