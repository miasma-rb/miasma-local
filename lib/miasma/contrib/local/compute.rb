require 'miasma'
require 'miasma/contrib/local'
require 'elecksee'
require 'tempfile'

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
            if(server.metadata && server.metadata[:ephemeral])
              elxc = Lxc::Ephemeral.new(
                :original => server.image_id,
                :daemon => true,
                :new_name => server.name
              )
              elxc.create!
              elxc.start!(:detach)
              lxc = elxc.lxc
            else
              lxc = Lxc::Clone.new(
                :original => server.image_id,
                :new_name => server.name
              ).clone!
            end
            lxc.start
            m_data = Smash.new(
              :name => server.name,
              :ephemeral => server.metadata[:ephemeral],
              :image_id => server.image_id,
              :flavor_id => server.flavor_id
            )
            m_data_path = lxc.path.join('miasma.json').to_s
            if(File.writable?(File.dirname(m_data_path)))
              File.open(m_data_path, 'w') do |file|
                file.write MultiJson.dump(m_data)
              end
            else
              t_file = Tempfile.new('miasma-local-compute')
              t_file.write MultiJson.dump(m_data)
              t_file.close
              lxc.run_command(
                "mv #{t_file.path} #{m_data_path}",
                :sudo => true
              )
            end
            server.load_data(
              server_info(lxc)
            ).valid_state
          end
        end

        # Reload the server data
        #
        # @param server [Miasma::Models::Compute::Server]
        # @return [Miasma::Models::Compute::Server]
        def server_reload(server)
          if(server.persisted?)
            lxc = Lxc.new(
              File.basename(server.id),
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
              File.basename(server.id),
              :base_path => File.dirname(server.id)
            )
            if(lxc.exists?)
              if(lxc.running?)
                lxc.stop
              end
              if(lxc.exists?) # ephemeral self-clean
                lxc.destroy
              end
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
            meta_path = lxc.path.join('miasma.json').to_s
            if(File.exists?(meta_path))
              sys_info = MultiJson.load(File.read(meta_path)).to_smash
            else
              info_path = lxc.rootfs.join('etc/os-release').to_s
              if(File.exists?(info_path))
                sys_info = Smash[
                  File.read(info_path).split("\n").map do |line|
                    line.split('=', 2).map do |item|
                      item.gsub(/(^"|"$)/, '')
                    end
                  end
                ]
                sys_info[:image_id] = [
                  sys_info.fetch('ID', 'unknown-system'),
                  sys_info.fetch('VERSION_ID', 'unknown-version')
                ].join('_').tr('.', '')
                sys_info[:name] = lxc.name
              else
                sys_info = Smash.new
              end
            end

            Smash.new(
              :id => lxc.path.to_s,
              :name => sys_info[:name],
              :state => lxc.state,
              :image_id => sys_info.fetch(:image_id, 'unknown'),
              :flavor_id => sys_info.fetch(:flavor_id, 'unknown'),
              :addresses_public =>  lxc.running? ? [
                Server::Address.new(
                  :version => 4,
                  :address => lxc.container_ip
                )
              ] : [],
              :addresses_private => [],
              :status => lxc.state.to_s,
              :metadata => Smash.new(
                :ephemeral => sys_info[:ephemeral]
              )
            )
          else
            Smash.new(
              :id => lxc.path.to_s,
              :name => lxc.name,
              :image_id => 'unknown',
              :flavor_id => 'unknown',
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
