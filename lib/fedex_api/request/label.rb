require 'fedex_api/request/base'
require 'fedex_api/label'
require 'fedex_api/request/shipment'
require 'fileutils'

module FedexApi
  module Request
    class Label < Shipment
      def initialize(credentials, options={})
        super(credentials, options)
        @filename = options[:filename]
      end

      private

      def success_response(api_response, response)
        super

        label_details = response.merge!({
          :format => @label_specification[:image_type],
          :file_name => @filename
        })

        FedexApi::Label.new label_details
      end

    end
  end
end
