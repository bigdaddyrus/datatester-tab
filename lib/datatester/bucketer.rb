require 'murmurhash3'

require_relative "./utils"

module DataTester
  class Bucketer
    BUCKET_SIZE = 1000

    def self.find_bucket(value, weights)
      index = hash_index(value)
      total_weight = weights.inject(0) { |sum, x| sum + x }
      weights = Utils.allocate_weights(weights.length) if total_weight.zero?
      Utils.bisect(weights, index)
    end

    def self.hash_index(buketing_key)
      index = hash_value(buketing_key) % BUCKET_SIZE
      index.negative? ? index + BUCKET_SIZE : index
    end

    def self.hash_value(bucketing_key)
      [MurmurHash3::V32.str_hash(bucketing_key)].pack('i').unpack('i').first()
    end
  end
end
