require 'miasma'

module Miasma
  module Contrib

    # Local API core helper
    class LocalApiCore

      # Common API methods
      module ApiCommon

        # Set attributes into model
        #
        # @param klass [Class]
        def self.included(klass)
          klass.class_eval do
            attribute :object_store_root, String
          end
        end

      end

    end
  end

  Models::Storage.autoload :Local, 'miasma/contrib/local/storage'
end
