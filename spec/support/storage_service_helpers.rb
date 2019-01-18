# frozen_string_literal: true

module RSpec
  module Support
    module StorageServiceHelpers
      def storage_service(storage_service)
        ActiveStorage::Service.configure(
          storage_service, ::Rails.configuration.active_storage.service_configurations
        )
      end

      def with_storage_service(storage_service)
        service = ActiveStorage::Blob.service
        begin
          ActiveStorage::Blob.service = storage_service(storage_service)
          yield
        ensure
          ActiveStorage::Blob.service = service
        end
      end
    end
  end
end
