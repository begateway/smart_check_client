# frozen_string_literal: true

require 'logger'

module SmartCheck
  class InfoLogger
    def initialize(logger)
      @logger = logger
    end

    def debug(*args, &block)
      @logger.info(*args, &block)
    end

    def info(*args, &block)
      @logger.info(*args, &block)
    end

    def warn(*args, &block)
      @logger.warn(*args, &block)
    end

    def error(*args, &block)
      @logger.error(*args, &block)
    end
  end

  class Client
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_TIMEOUT = 10

    attr_reader :user_id, :password, :url, :opts, :headers, :open_timeout, :timeout
    cattr_accessor :proxy

    def initialize(params)
      @url = params.fetch(:url)
      @user_id = params[:user_id]
      @password = params[:password]
      @opts = params[:options] || {}
      @headers = @opts[:headers] || {}
      @logger = params[:logger]
      @open_timeout = params[:open_timeout] || DEFAULT_OPEN_TIMEOUT
      @timeout = params[:timeout] || DEFAULT_TIMEOUT
    end

    # POST /api/v1/users — no auth required
    def create_user(params)
      post_request('/api/v1/users', params, false)
    end

    # POST /api/v1/transactions — basic auth required
    def create_transaction(params)
      post_request('/api/v1/transactions', params, true)
    end

    # POST /api/v1/transactions/local — basic auth required
    # Returns transactions statistics within the requesting PSP scope.
    def transactions_local(params)
      post_request('/api/v1/transactions/local', params, true)
    end

    # POST /api/v1/transactions/global — basic auth required
    # Returns transactions statistics across all PSPs.
    def transactions_global(params)
      post_request('/api/v1/transactions/global', params, true)
    end

    private

    attr_reader :response

    def logger
      return nil unless @logger

      InfoLogger.new(@logger)
    end

    def request
      response = yield
      Response.new(response.status.to_s, response.body)
    rescue StandardError, Faraday::ClientError => e
      logger&.error("[SmartCheck::Client] Connection error: [#{e.class}] #{e.message}\n#{e.backtrace&.join("\n")}")

      Response.new('500', {
        'status' => 'failed',
        'message' => "Failed to complete SmartCheck::Client request. Error message: #{e.message}"
      }.to_json)
    end

    def connection(with_auth)
      Faraday::Connection.new(opts) do |c|
        c.options[:open_timeout] ||= open_timeout
        c.options[:timeout] ||= timeout
        c.options[:proxy] = proxy if proxy
        c.request :json

        c.response :logger, logger, { headers: true, bodies: true, log_level: :info } do |l|
          l.filter(/(Authorization:) .+/, '\1 [FILTERED]')
        end

        c.headers = { 'Content-Type' => 'application/json' }.update(headers.to_h)

        c.basic_auth(user_id, password) if with_auth && user_id && password
        c.adapter Faraday.default_adapter
      end
    end

    def post_request(path, data, with_auth)
      request { connection(with_auth).post(full_path(path), data.to_json) }
    end

    def full_path(path)
      [url, path].join
    end
  end
end
