# lib/decision.rb

require_relative './meta'
require_relative './diversion_flight'
require_relative './diversion_feature'

module DataTester
  class Diversion
    def initialize(token, diversion_key = 'ssid')
      @meta = Meta.instance

      @diversion_feature = FeatureDiversion.new(token, diversion_key = diversion_key)
      @diversion_flight = FlightDiversion.new(token, diversion_key = diversion_key)
    end

    def divert(user_data)
      flight_divert_result = @diversion_flight.divert(user_data)
      feature_divert_result = @diversion_feature.divert(user_data)

      config = {}
      config.merge!(feature_divert_result['feature_config']) unless feature_divert_result.nil?
      config.merge!(flight_divert_result['version_config']) unless flight_divert_result.nil?

      [flight_divert_result['version_ids'], config]
    end

    def url_prefix(domain)
      @meta.domain = domain
    end
  end
end
