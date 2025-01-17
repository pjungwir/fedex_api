require 'fedex_api/request/base'

module FedexApi
  module Request
    class Rate < Base
      # Sends post request to Fedex web service and parse the response, a Rate object is created if the response is successful
      def process_request
        req = build_xml
        puts req if @debug
        api_response = self.class.post(api_url, :body => req)
        puts api_response if @debug
        response = parse_response(api_response)
        if success?(response)
          rate_reply_details = response[:rate_reply][:rate_reply_details] || []
          rate_reply_details = [rate_reply_details] if rate_reply_details.is_a?(Hash)

          rate_reply_details.map do |rate_reply|
            rate_details = [rate_reply[:rated_shipment_details]].flatten.first[:shipment_rate_detail]
            rate_details.merge!(service_type: rate_reply[:service_type])
            rate_details.merge!(transit_time: rate_reply[:transit_time])
            rate_details.merge!(delivery_timestamp: rate_reply[:delivery_timestamp])
            rate_details.merge!(response_details: rate_reply)
            FedexApi::Rate.new(rate_details)
          end
        else
          error_message = 
            if response[:rate_reply]
              [response[:rate_reply][:notifications]].flatten.first[:message]
            elsif response.dig(:csr_error, :message)
              response.dig(:csr_error, :message)
            else
              "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n--#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
            end rescue $1
          raise RateError, error_message
        end
      end

      private

      # Add information for shipments
      def add_requested_shipment(xml)
        xml.RequestedShipment{
          xml.ShipTimestamp @shipping_options[:ship_timestamp] ||= Time.now.utc.iso8601(2)
          xml.DropoffType @shipping_options[:drop_off_type] ||= "REGULAR_PICKUP"
          xml.ServiceType service_type if service_type
          xml.PackagingType @shipping_options[:packaging_type] ||= "YOUR_PACKAGING"
          add_shipper(xml)
          add_recipient(xml)
          add_shipping_charges_payment(xml)
          add_customs_clearance(xml) if @customs_clearance_detail
          xml.RateRequestTypes "ACCOUNT"
          add_packages(xml)
        }
      end

      # Add transite time options
      def add_transit_time(xml)
        xml.ReturnTransitAndCommit true
      end

      # Build xml Fedex Web Service request
      def build_xml
        ns = "http://fedex.com/ws/rate/v#{service[:version]}"
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.RateRequest(:xmlns => ns){
            add_web_authentication_detail(xml)
            add_client_detail(xml)
            add_version(xml)
            add_transit_time(xml)
            add_requested_shipment(xml)
          }
        end
        builder.doc.root.to_xml
      end

      def service
        { :id => 'crs', :version => FedexApi::API_VERSION }
      end

      # Successful request
      def success?(response)
        response[:rate_reply] &&
          %w{SUCCESS WARNING NOTE}.include?(response[:rate_reply][:highest_severity])
      end

    end
  end
end
