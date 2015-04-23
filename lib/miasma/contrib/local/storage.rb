require 'miasma'
require 'miasma/contrib/local'
require 'fileutils'
require 'tempfile'
require 'mime-types'

module Miasma
  module Models
    class Storage
      class Local < Storage

        include Contrib::LocalApiCore::ApiCommon

        # Create new instance
        #
        # @param args [Hash]
        # @return [self]
        def initialize(args={})
          super
          unless(::File.directory?(object_store_root))
            FileUtils.mkdir_p(object_store_root)
          end
        end

        # Save bucket
        #
        # @param bucket [Models::Storage::Bucket]
        # @return [Models::Storage::Bucket]
        def bucket_save(bucket)
          unless(bucket.persisted?)
            FileUtils.mkdir_p(full_path(bucket))
            bucket.id = bucket.name
            bucket.valid_state
          end
          bucket
        end

        # Destroy bucket
        #
        # @param bucket [Models::Storage::Bucket]
        # @return [TrueClass, FalseClass]
        def bucket_destroy(bucket)
          if(bucket.persisted?)
            FileUtils.rmdir(full_path(bucket))
            true
          else
            false
          end
        end

        # Reload the bucket
        #
        # @param bucket [Models::Storage::Bucket]
        # @return [Models::Storage::Bucket]
        def bucket_reload(bucket)
          if(bucket.persisted?)
            unless(::File.directory?(full_path(bucket)))
              bucket.data.clear
              bucket.dirty.clear
            else
              bucket.valid_state
            end
          end
          bucket
        end

        # Return all buckets
        #
        # @return [Array<Models::Storage::Bucket>]
        def bucket_all
          Dir.new(object_store_root).map do |item|
            if(::File.directory?(::File.join(object_store_root, item)) && !item.start_with?('.'))
              Bucket.new(
                self,
                :id => ::File.basename(uri_unescape(item)),
                :name => ::File.basename(uri_unescape(item))
              ).valid_state
            end
          end.compact
        end

        # Return filtered files
        #
        # @param args [Hash] filter options
        # @return [Array<Models::Storage::File>]
        def file_filter(bucket, args)
          Dir.glob(::File.join(full_path(bucket), uri_escape(args[:prefix]), '*')).map do |item|
            if(::File.file?(item) && !item.start_with?('.'))
              item_name = item.sub("#{full_path(bucket)}/", '')
              item_name = uri_unescape(item_name)
              File.new(
                bucket,
                :id => ::File.join(bucket.name, item_name),
                :name => item_name,
                :updated => File.mtime(item),
                :size => File.size(item)
              ).valid_state
            end
          end.compact
        end

        # Return all files within bucket
        #
        # @param bucket [Bucket]
        # @return [Array<File>]
        # @todo pagination auto-follow
        def file_all(bucket)
          Dir.glob(::File.join(full_path(bucket), '*')).map do |item|
            if(::File.file?(item) && !item.start_with?('.'))
              item_name = item.sub("#{full_path(bucket)}/", '')
              item_name = uri_unescape(item_name)
              File.new(
                bucket,
                :id => ::File.join(bucket.name, item_name),
                :name => item_name,
                :updated => ::File.mtime(item),
                :size => ::File.size(item)
              ).valid_state
            end
          end.compact
        end

        # Save file
        #
        # @param file [Models::Storage::File]
        # @return [Models::Storage::File]
        def file_save(file)
          if(file.dirty?)
            file.load_data(file.attributes)
            if(file.attributes[:body].respond_to?(:readpartial))
              file.body.rewind
              tmp_file = Tempfile.new('miasma')
              begin
                while(content = file.body.read(Storage::READ_BODY_CHUNK_SIZE))
                  tmp_file.write content
                end
              rescue EOFError
              end
              tmp_file.flush
              tmp_file.close
              FileUtils.mv(tmp_file.path, full_path(file))
            end
            file.id = ::File.join(file.bucket.name, file.name)
            file.reload
          end
          file
        end

        # Destroy file
        #
        # @param file [Models::Storage::File]
        # @return [TrueClass, FalseClass]
        def file_destroy(file)
          if(file.persisted?)
            FileUtils.rm(full_path(file))
            true
          else
            false
          end
        end

        # Reload the file
        #
        # @param file [Models::Storage::File]
        # @return [Models::Storage::File]
        def file_reload(file)
          if(file.persisted?)
            new_info = Smash.new.tap do |data|
              data[:updated] = ::File.mtime(full_path(file))
              data[:size] = ::File.size(full_path(file))
              data[:etag] = Digest::MD5.hexdigest(::File.read(full_path(file))) # @todo Update for block building
              mime = MIME::Types.of(full_path(file)).first
              if(mime)
                data[:content_type] = mime.content_type
              end
            end
            file.load_data(file.attributes.deep_merge(new_info))
            file.valid_state
          end
          file
        end

        # Create publicly accessible URL
        #
        # @param timeout_secs [Integer] seconds available
        # @return [String] URL
        # @todo where is this in swift?
        def file_url(file, timeout_secs)
          if(file.persisted?)
            "file://#{full_path(file)}"
            full_path(file)
          else
            raise Error::ModelPersistError.new "#{file} has not been saved!"
          end
        end

        # Fetch the contents of the file
        #
        # @param file [Models::Storage::File]
        # @return [IO, HTTP::Response::Body]
        def file_body(file)
          if(file.persisted?)
            tmp_file = Tempfile.new('miasma')
            tmp_path = tmp_file.path
            tmp_file.delete
            FileUtils.cp(full_path(file), tmp_path)
            File::Streamable.new(::File.open(tmp_path, 'rb'))
          else
            StringIO.new('')
          end
        end

        # @return [String] escaped bucket name
        def bucket_path(bucket)
          ::File.join(object_store_root, uri_escape(bucket.name))
        end

        # @return [String] escaped file path
        def file_path(file)
          uri_escape(file.name)
        end

        # Provide full path for object
        #
        # @param file_or_bucket [File, Bucket]
        # @return [String]
        def full_path(file_or_bucket)
          if(file_or_bucket.is_a?(Bucket))
            bucket_path(file_or_bucket)
          else
            ::File.join(
              bucket_path(file_or_bucket.bucket),
              file_path(file_or_bucket)
            )
          end
        end

        # URL string escape
        #
        # @param string [String] string to escape
        # @return [String] escaped string
        # @todo move this to common module
        def uri_escape(string)
          string.to_s.gsub(/([^a-zA-Z0-9_.\-~])/) do
            '%' << $1.unpack('H2' * $1.bytesize).join('%').upcase
          end
        end

        # Un-escape URL escaped string
        #
        # @param string [String]
        # @return [String]
        def uri_unescape(string)
          string.to_s.gsub(/%([^%]{2})/) do
            [$1].pack('H2')
          end
        end

      end
    end
  end
end
