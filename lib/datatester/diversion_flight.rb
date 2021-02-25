# lib/decision_feature.rb

require_relative './meta'
require_relative './filters'
require_relative './bucketer'
require_relative './utils'

module DataTester
  class FlightDiversion
    def initialize(token, diversion_key = 'ssid')
      @token = token
      @diversion_key = diversion_key
      @meta = Meta.instance
      @filters = Filters.new
    end

    def divert(user_data)
      return nil unless user_data.include?(@diversion_key)

      user_id = user_data[@diversion_key]
      layers = @meta.layers(@token)

      divert_layers(layers, @meta.flights(@token), user_id, user_data)
    end

    def son_flight?(flight)
      !flight.fetch('father_flight_id', nil).nil?
    end

    def divert_layers(layers, flights, user_id, user_data)
      version_ids = []
      version_config = {}
      father_vids = []

      for layer in layers
        test_user_version = layer['test_user'].fetch(user_id, nil)
        unless test_user_version.nil?
          version_ids.push(test_user_version['id'])
          version_config.merge!(test_user_version['config'])

          father_versions = test_user_version.fetch('father_versions', nil)
          father_ids.push(test_user_version['id']) unless father_versions.nil?
          next
        end

        flight_id = choose_flight(layer, user_id)
        next if flight_id == -1

        flight = flights[flight_id.to_s]

        version = if son_flight? flight
                    divert_son_flight(flight, user_id, user_data, father_vids)
                  else
                    divert_father_flight(flight, user_id, user_data)
                  end

        next if version.nil?

        father_vids.push(version['id']) unless son_flight? flight
        version_ids.push(version['id'])
        version_config.merge!(version['config'])
      end

      {
        'version_ids' => version_ids,
        'version_config' => version_config
      }
    end

    def choose_flight(layer, user_id)
      layer_name = layer['name']
      traffic_info, flights = layer['traffic_map']
      index = Bucketer.find_bucket("#{user_id}:#{layer_name}", traffic_info)
      flights[index]
    end

    def divert_son_flight(flight, user_id, user_data, father_vids)
      return nil unless son_flight?(flight)

      version = divert_flight(flight, user_id, user_data)
      return nil if version.nil?

      father_versions = version.fetch('father_versions', [])
      return version if father_versions.nil? || father_versions.empty?

      (father_versions & father_vids).any? ? version : nil
    end

    def divert_father_flight(flight, user_id, user_data)
      return nil if son_flight?(flight)

      divert_flight(flight, user_id, user_data)
    end

    def divert_flight(flight, user_id, user_data)
      rules = flight['filter']
      return nil unless @filters.statisfied?(rules, user_data)

      versions = flight['versions']
      weights = versions.map { |version| version.fetch('weight', 0) }
      accumulate_weights = Utils.accumulate!(weights)

      flight_name = flight['name']
      bucket = Bucketer.find_bucket("#{user_id}:#{flight_name}", accumulate_weights)

      versions[bucket]
    end
  end
end
