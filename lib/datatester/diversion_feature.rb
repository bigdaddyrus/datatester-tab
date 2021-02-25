require_relative './meta'
require_relative './filters'
require_relative './bucketer'
require_relative './utils'

module DataTester
  class FeatureDiversion
    def initialize(token, diversion_key = 'ssid')
      @token = token
      @diversion_key = diversion_key
      @meta = Meta.instance
      @filters = Filters.new
    end

    def divert(user_data)
      return nil unless user_data.include?(@diversion_key)

      user_id = user_data[@diversion_key]
      features = @meta.features(@token)

      {
        'feature_config' => divert_features(features, user_id, user_data)
      }
    end

    def divert_features(features, user_id, user_data)
      config = {}
      features.map do |feature|
        variants = feature['white_list'].fetch(user_id, nil)
        unless variants.nil?
          variants.each { |variant| config.merge!(variant['config']) }
          next
        end

        default_config = feature.fetch('default_variant', {})

        config.merge!(divert_feature(feature, user_id, user_data, default_config))
      end
      config
    end

    def divert_feature(feature, user_id, user_data, default_config)
      return default_config if feature['filters'].nil? || feature['filters'].empty?

      config = {}
      feature_name = feature['name']
      rank = feature['filters'].length

      variant_config = []

      feature['filters'].sort.each do |_id, filter|
        if filter['type'] == 'default' || !@filters.statisfied?(filter['filter_backend'], user_data)
          # config.merge!(default_config) unless default_config.nil?
          next
        end

        variants = filter['variants']
        accumulate_weights = Utils.accumulate!(variants.map { |variant| variant['weight'] })
        bucket = Bucketer.find_bucket("#{user_id}:#{feature_name}", accumulate_weights)

        variant = variants[bucket]
        if filter['rank'] < rank && !variant.nil?
          variant_config.push(variant['config'])
          rank = filter['rank']
        end
      end

      variant_config.push(default_config) if variant_config.length.zero?
      variant_config.each { |c| config.merge!(c) unless c.nil? }
      config
    end
  end
end
