# lib/meta.rb

require 'singleton'
require 'faraday'
require 'json'

module DataTester
  class Meta
    include Singleton
    attr_writer :domain, :timeout, :interval

    CLIENT = 'client'
    URL_DOMAIN = 'https://data.bytedance.com'
    TIMEOUT = 60
    FETCH_INTERVAL = 30

    def self.instance
      @instance ||= new
    end

    def initialize()
      @timeout = TIMEOUT
      @interval = FETCH_INTERVAL
      @domain = URL_DOMAIN
      @data = {}

      download_all
    end

    def features(token)
      get_data(token, 'features')
    end

    def flights(token)
      get_data(token, 'flights')
    end

    def layers(token)
      get_data(token, 'layers')
    end

    private

    def download_all()
      Thread.new do
        loop do
          tokens = @data.keys
          tokens.each do |token|
            @data[token] = download(token)
          end
          sleep(@interval)
        end
      end
    end

    def normalize(data)
      config = {}
      config.merge!(normalize_layers(data.fetch('layers', nil)))
      config.merge!(normalize_features(data.fetch('flags', nil)))
    end

    def get_data(token, key)
      @data[token] = download(token) unless @data.include?(token)
      @data[token][key]
    end

    def download(token)
      res = Faraday.get("#{@domain}/abmeta/get_abtest_info/?token=#{token}")
      normalize(JSON.parse(res.body))
    end

    def normalize_layers(layers)
      return { 'layers' => [], 'flights' => {} } if layers.nil?

      flights = {}
      layer_list = []

      layers.sort.each do |_, layer|
        normalized_layer, normalized_flight = normalize_layer(layer)
        layer_list.push(normalized_layer)
        flights.merge!(normalized_flight)
      end

      {
        'layers' => layer_list,
        'flights' => flights
      }
    end

    def normalize_flight(flight)
      return nil if flight['name'].empty?
      return nil if flight['versions'].empty?
      return nil unless flight.include?('filter')

      flight
    end

    def normalize_layer(layer)
      traffic_map = normalize_traffic_map(layer['traffic_map'].fetch('traffic_info', {}))
      layer_dict = {
        'traffic_map' => traffic_map,
        'name' => layer['name']
      }

      test_user = {}
      flight_dict = {}

      layer['flights'].sort.each do |id, flight|
        normalized_flight = normalize_flight(flight)
        next if normalized_flight.nil?

        flight_dict[id] = normalized_flight

        flight['versions'].each do |version|
          version['user_list'].each { |user| test_user[user] = version }
        end
      end

      layer_dict.merge!({ 'test_user' => test_user })
      [layer_dict, flight_dict]
    end

    def normalize_traffic_map(traffic_map)
      pieces = traffic_map.fetch('pieces', [])

      steps = [0]
      flights = [-1]

      pieces.each do |piece|
        next if piece.empty?

        if piece['begin'] != steps[-1]
          steps.push(piece['begin'])
          flights.push(-1)
        end

        steps.push(piece['begin'] + piece['length'])
        flights.push(piece['flight'])
      end

      flights.push(-1)

      [steps, flights]
    end

    def normalize_features(features)
      return {'features' => []} if features.nil?
      {
        'features' => features.map { |_, feature| normalize_feature(feature) }.filter { |feature| !feature.nil? }
      }
    end

    def normalize_feature(feature)
      return nil if feature['side_type'] == CLIENT
      return nil unless feature_active?(feature)

      filters = feature.fetch('filters', nil)
      return feature.merge!({ 'white_list' => {} }) if filters.nil?

      white_list = {}

      filters.sort.each do |_id, filter|
        next if filter['variants'].empty?

        filter['variants'].each do |variant|
          variant.fetch('user_list', []).each do |user|
            variants = white_list.fetch(user, [])
            variants.push(variant)
            white_list[user] = variants
          end
        end
      end

      feature.merge!({ 'white_list' => white_list })
    end

    def feature_active?(feature)
      !(feature['status'].zero? || feature['deleted'] == 1)
    end
  end
end
