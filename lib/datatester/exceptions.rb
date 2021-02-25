module DataTester
  class HTTPCallError < StandardError
    def initialize(msg = 'HTTP call resulted in a response with an error code.')
      super
    end
  end
end
