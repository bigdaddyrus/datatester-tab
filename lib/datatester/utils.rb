# lib/utils.rb

module DataTester
  class Utils
    def self.bisect(sects, value)
      length = sects.length
      for index in 0..length - 1
        return index if value < sects[index]
      end
      length
    end

    def self.accumulate!(weights)
      sum = 0
      weights.map { |x| sum += x }
    end

    def self.allocate_weights(num, max_size = 1000)
      step = max_size / num
      sum = 0
      weights = (1..num).map { |_| sum += step }
      weights[-1] = max_size
      weights
    end
  end
end
