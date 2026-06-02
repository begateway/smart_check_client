# frozen_string_literal: true

module SmartCheck
  class Response
    SUCCESSFUL_STATUS = 'successful'.freeze

    attr_reader :http_code, :data

    def initialize(http_code, body)
      @http_code = http_code
      @data = begin
                JSON.parse(body)
              rescue JSON::ParserError, TypeError
                {}
              end
    end

    def success?
      data['status'] == SUCCESSFUL_STATUS && (200..299).include?(http_code.to_i)
    end

    def status
      data['status']
    end

    def message
      data['message'].presence || (success? ? 'Successful executed' : 'Executed with error')
    end

    def errors
      data['errors']
    end

    def id
      data['id']
    end

    def stats
      data['data']
    end
  end
end
