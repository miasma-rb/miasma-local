require 'miasma'
require 'miasma/contrib/local'
require 'elecksee'

module Miasma
  module Models
    class Compute
      class Local < Compute

        include Contrib::LocalApiCore::ApiCommon

        # Provide full list of server instances
        #
        # @return [Array<Miasma::Models::Compute::Server>]
        def server_all
          c_roots = Dir.glob(
            File.join(container_root, '*')
          ).find_all do |g_path|
            File.directory?(g_path)
          end
          c_roots.map do |c_path|
            lxc = Lxc.new(
              File.basename(c_path),
              :base_path => File.dirname(c_path)
            )
            Server.new(
              self,
              :id => lxc.path.to_s,
              :name => lxc.name,
              :state => lxc.state,
              :image_id => 'unknown',
              :flavor_id => 'unknown',
              :addresses_public =>  lxc.running? ? [
                Server::Address.new(
                  :version => 4,
                  :address => lxc.container_ip
                )
              ] : [],
              :addresses_private => [],
              :status => lxc.state.to_s
            ).valid_state
          end
        end

        # Reload the server data
        #
        # @param server [Miasma::Models::Compute::Server]
        # @return [Miasma::Models::Compute::Server]
        def server_save(server)

        end

        def server_reload(obj)
        end

        def server_destroy(obj)
        end

      end
    end
  end
end
