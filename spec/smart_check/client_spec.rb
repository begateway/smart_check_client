# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe SmartCheck::Client do
  let(:url)      { 'https://smart-check-staging.begateway.com' }
  let(:user_id)  { 'paysage' }
  let(:password) { 'secret' }

  let(:client) do
    described_class.new(url: url, user_id: user_id, password: password)
  end

  let(:basic_auth_header) do
    "Basic #{Base64.strict_encode64("#{user_id}:#{password}")}"
  end

  describe '#initialize' do
    it 'sets attributes' do
      expect(client.url).to eq(url)
      expect(client.user_id).to eq(user_id)
      expect(client.password).to eq(password)
      expect(client.open_timeout).to eq(5)
      expect(client.timeout).to eq(10)
    end

    it 'requires url' do
      expect { described_class.new(user_id: user_id, password: password) }.to raise_error(KeyError)
    end

    it 'allows custom timeouts' do
      c = described_class.new(url: url, user_id: user_id, password: password, open_timeout: 1, timeout: 2)
      expect(c.open_timeout).to eq(1)
      expect(c.timeout).to eq(2)
    end

    it 'allows custom headers' do
      c = described_class.new(url: url, user_id: user_id, password: password, options: { headers: { 'X-Request-Id' => 'abc' } })
      expect(c.headers).to eq('X-Request-Id' => 'abc')
    end
  end

  describe '#create_user' do
    let(:body) do
      {
        'status' => 'successful',
        'message' => 'Created.',
        'id' => 'a4704d27-073b-41db-996f-44174e0f5f82'
      }
    end

    it 'POSTs to /api/v1/users without basic auth' do
      stub = stub_request(:post, "#{url}/api/v1/users")
             .with(body: { 'username' => 'new_user', 'password' => 'enc' }.to_json)
             .with { |req| !req.headers.key?('Authorization') }
             .to_return(status: 201, body: body.to_json)

      response = client.create_user(username: 'new_user', password: 'enc')
      expect(stub).to have_been_requested
      expect(response.success?).to eq(true)
      expect(response.id).to eq('a4704d27-073b-41db-996f-44174e0f5f82')
    end

    it 'returns failure on 400' do
      stub_request(:post, "#{url}/api/v1/users")
        .to_return(status: 400, body: { 'status' => 'failed', 'message' => 'Authorization error.' }.to_json)

      response = client.create_user(username: 'x', password: 'y')
      expect(response.success?).to eq(false)
      expect(response.message).to eq('Authorization error.')
    end
  end

  describe '#create_transaction' do
    let(:params) do
      {
        id: 'e3b10b9d-7a92-4323-9360-56047d7219c2',
        card_pan: '4200000000000000',
        status: 'successful',
        type: 'payment',
        created_at: '2023-01-11T14:02:20.449Z'
      }
    end

    it 'POSTs to /api/v1/transactions with basic auth' do
      stub = stub_request(:post, "#{url}/api/v1/transactions")
             .with(headers: { 'Authorization' => basic_auth_header })
             .to_return(status: 201, body: { 'status' => 'successful', 'message' => 'Created.' }.to_json)

      response = client.create_transaction(params)
      expect(stub).to have_been_requested
      expect(response.success?).to eq(true)
      expect(response.message).to eq('Created.')
    end
  end

  describe '#transactions_local' do
    let(:smart_check_payload) do
      {
        card_pan: '4200000000000000',
        date_from: '2025-11-06T12:00:00Z',
        types: %w[payment payout capture refund chargeback authorization],
        statuses: %w[successful],
        trx_dates_in_response: true
      }
    end

    let(:body) do
      {
        'status' => 'successful',
        'message' => 'Credit card statistics',
        'data' => {
          'payment' => {
            'successful' => {
              'count' => 13,
              'first_transaction_at' => '2025-01-01T10:00:00.123Z',
              'last_transaction_at' => '2026-01-01T02:15:45.123Z'
            }
          }
        }
      }
    end

    it 'POSTs to /api/v1/transactions/local with basic auth and json body' do
      stub = stub_request(:post, "#{url}/api/v1/transactions/local")
             .with(
               headers: { 'Authorization' => basic_auth_header, 'Content-Type' => 'application/json' },
               body: smart_check_payload.to_json
             )
             .to_return(status: 200, body: body.to_json)

      response = client.transactions_local(smart_check_payload)
      expect(stub).to have_been_requested
      expect(response.success?).to eq(true)
      expect(response.stats).to eq(body['data'])
    end
  end

  describe '#transactions_global' do
    it 'POSTs to /api/v1/transactions/global with basic auth' do
      stub = stub_request(:post, "#{url}/api/v1/transactions/global")
             .with(headers: { 'Authorization' => basic_auth_header })
             .to_return(status: 200, body: { 'status' => 'successful', 'message' => 'Credit card statistics', 'data' => {} }.to_json)

      response = client.transactions_global(card_pan: '4200000000000000')
      expect(stub).to have_been_requested
      expect(response.success?).to eq(true)
    end
  end

  describe 'logging' do
    let(:output) { StringIO.new }
    let(:client) do
      described_class.new(url: url, user_id: user_id, password: password, logger: Logger.new(output))
    end

    it 'filters authorization and PAN without changing the authenticated request' do
      params = { card_pan: '4200000000000000', date_from: '2025-01-01' }
      stub = stub_request(:post, "#{url}/api/v1/transactions/local")
        .with(headers: { 'Authorization' => basic_auth_header }, body: params.to_json)
        .to_return(status: 200, body: { status: 'successful', data: {} }.to_json)

      expect(client.transactions_local(params)).to be_success
      expect(stub).to have_been_requested.once
      expect(output.string).to include('Authorization: [FILTERED]', '2025-01-01')
      expect(output.string).not_to include(basic_auth_header, params[:card_pan])
    end

    it 'filters the complete registration password, including escaped characters' do
      params = { username: 'log-filter-test', password: "synthetic-\"quoted\"-\\password!" }
      stub = stub_request(:post, "#{url}/api/v1/users")
        .with(body: params.to_json)
        .with { |request| !request.headers.key?('Authorization') }
        .to_return(status: 201, body: { status: 'successful' }.to_json)

      expect(client.create_user(params)).to be_success
      expect(stub).to have_been_requested.once
      expect(output.string).to include('"password":"[FILTERED]"', params[:username])
      expect(output.string).not_to include('synthetic-', 'quoted', params[:password].to_json)
    end

    it 'filters sensitive response fields while preserving the returned response' do
      body = { status: 'successful', data: { password: 'response-secret', card_pan: '4200000000000000' } }
      stub_request(:post, "#{url}/api/v1/transactions/global")
        .to_return(status: 200, body: JSON.pretty_generate(body))

      response = client.transactions_global({})

      expect(response).to be_success
      expect(response.stats).to eq(body[:data].transform_keys(&:to_s))
      expect(output.string).to include('"password": "[FILTERED]"', '"card_pan": "[FILTERED]"')
      expect(output.string).not_to include('response-secret', body[:data][:card_pan])
    end
  end

  describe 'connection errors' do
    it 'wraps Faraday connection errors into a 500 Response' do
      stub_request(:post, "#{url}/api/v1/transactions/local")
        .to_raise(Faraday::ConnectionFailed.new('boom'))

      response = client.transactions_local(card_pan: '4200000000000000')
      expect(response).to be_a(SmartCheck::Response)
      expect(response.success?).to eq(false)
      expect(response.http_code).to eq('500')
      expect(response.message).to include('boom')
    end

    it 'wraps timeouts into a 500 Response' do
      stub_request(:post, "#{url}/api/v1/transactions/local").to_timeout

      response = client.transactions_local(card_pan: '4200000000000000')
      expect(response.success?).to eq(false)
      expect(response.http_code).to eq('500')
    end
  end

  describe 'proxy' do
    after { described_class.proxy = nil }

    let(:options) { {} }
    let(:client) { described_class.new(url: url, options: options, logger: Logger.new(StringIO.new)) }

    around do |example|
      keys = %w[http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY]
      saved = keys.map { |key| [key, ENV[key]] }.to_h
      keys.each { |key| ENV.delete(key) }
      ENV['http_proxy'] = ENV['https_proxy'] = 'http://environment-proxy:3142'
      example.run
    ensure
      saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end

    def transport_proxy
      observed = nil
      response = double(code: '200', body: '{"status":"successful"}', message: 'OK')
      allow(response).to receive(:each_header)
      expect_any_instance_of(Faraday::Adapter::NetHttp).to receive(:perform_request) do |*args|
        http = args.find { |arg| arg.is_a?(Net::HTTP) }
        observed = { enabled: http.proxy?, host: http.proxy_address, port: http.proxy_port }
        response
      end
      expect(client.transactions_global({})).to be_success
      observed
    end

    it 'uses the environment proxy when no proxy option is supplied' do
      expect(transport_proxy).to eq(enabled: true, host: 'environment-proxy', port: 3142)
    end

    it 'uses the global proxy when environment proxy is absent' do
      ENV.delete('http_proxy')
      ENV.delete('https_proxy')
      described_class.proxy = 'http://global-proxy:3128'
      expect(transport_proxy).to eq(enabled: true, host: 'global-proxy', port: 3128)
    end

    context 'with an explicit per-client proxy' do
      let(:options) { { proxy: 'http://dedicated-proxy:3129' } }

      it 'takes precedence over global and environment proxies' do
        described_class.proxy = 'http://global-proxy:3128'
        expect(transport_proxy).to eq(enabled: true, host: 'dedicated-proxy', port: 3129)
      end
    end

    context 'with an explicit nil proxy' do
      let(:options) { { proxy: nil } }

      it 'keeps the environment proxy behavior for a nil option' do
        described_class.proxy = 'http://global-proxy:3128'
        expect(transport_proxy).to eq(enabled: true, host: 'environment-proxy', port: 3142)
      end
    end

    it 'is configurable globally' do
      described_class.proxy = 'http://proxy.example.com:3128'
      expect(described_class.proxy).to eq('http://proxy.example.com:3128')
    end
  end
end
