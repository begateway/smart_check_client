# frozen_string_literal: true

require 'spec_helper'

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

    it 'is configurable globally' do
      described_class.proxy = 'http://proxy.example.com:3128'
      expect(described_class.proxy).to eq('http://proxy.example.com:3128')
    end
  end
end
