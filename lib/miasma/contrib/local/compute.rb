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
              server_info(lxc)
            ).valid_state
          end
        end

        # Save/create the server
        #
        # @param server [Miasma::Models::Compute::Server]
        # @return [Miasma::Models::Compute::Server]
        def server_save(server)
          if(server.persisted?)
            raise "What do we do?"
          else

          end
        end

        # Reload the server data
        #
        # @param server [Miasma::Models::Compute::Server]
        # @return [Miasma::Models::Compute::Server]
        def server_reload(server)
          if(server.persisted?)
            lxc = Lxc.new(
              server.name,
              :base_path => File.dirname(server.id)
            )
            server.load_data(
              server_info(lxc)
            ).valid_state
            server
          else
            server
          end
        end

        # Destroy the server
        #
        # @param server [Miasma::Models::Compute::Server]
        # @return [TrueClass, FalseClass]
        def server_destroy(server)
          if(server.persisted?)
            lxc = Lxc.new(
              server.name,
              :base_path => File.dirname(server.id)
            )
            if(lxc.exists?)
              if(lxc.running?)
                lxc.stop
              end
              lxc.destroy
            end
            true
          else
            false
          end
        end

        protected

        # Generate model attributes from container
        #
        # @param lxc [Lxc]
        # @return [Smash]
        def server_info(lxc)
          if(lxc.exists?)
            info_path = lxc.rootfs.join('etc/os-release').to_s
            if(File.exists?(info_path))
              sys_info = Smash[
                File.read(info_path).split("\n").map do |line|
                  line.split('=', 2).map do |item|
                    item.gsub(/(^"|"$)/, '')
                  end
                end
              ]
              image_id = [
                sys_info.fetch('ID', 'unknown-system'),
                sys_info.fetch('VERSION_ID', 'unknown-version')
              ].join('_')
            else
              sys_info = Smash.new
              image_id = 'unknown'
            end

            Smash.new(
              :id => lxc.path.to_s,
              :name => lxc.name,
              :state => lxc.state,
              :image_id => image_id,
              :flavor_id => 'unknown',
              :addresses_public =>  lxc.running? ? [
                Server::Address.new(
                  :version => 4,
                  :address => lxc.container_ip
                )
              ] : [],
              :addresses_private => [],
              :status => lxc.state.to_s
            )
          else
            Smash.new(
              :id => lxc.path.to_s,
              :name => lxc.name,
              :state => :terminated,
              :addresses_public => [],
              :addresses_private => [],
              :status => 'Destroyed'
            )
          end
        end

      end
    end
  end
end
