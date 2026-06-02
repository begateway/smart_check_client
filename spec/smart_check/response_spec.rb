# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SmartCheck::Response do
  describe '#success?' do
    it 'is true when status=successful and http 2xx' do
      response = described_class.new('200', { 'status' => 'successful', 'message' => 'ok' }.to_json)
      expect(response.success?).to eq(true)
    end

    it 'is false when http is non-2xx even if status=successful' do
      response = described_class.new('500', { 'status' => 'successful' }.to_json)
      expect(response.success?).to eq(false)
    end

    it 'is false when status=failed' do
      response = described_class.new('200', { 'status' => 'failed', 'message' => 'oops' }.to_json)
      expect(response.success?).to eq(false)
    end

    it 'is false on empty body' do
      response = described_class.new('200', '')
      expect(response.success?).to eq(false)
    end

    it 'is false on invalid json body' do
      response = described_class.new('200', 'not-a-json')
      expect(response.success?).to eq(false)
    end
  end

  describe '#message' do
    it 'returns message from body' do
      response = described_class.new('200', { 'status' => 'successful', 'message' => 'Created.' }.to_json)
      expect(response.message).to eq('Created.')
    end

    it 'returns default success message when missing' do
      response = described_class.new('200', { 'status' => 'successful' }.to_json)
      expect(response.message).to eq('Successful executed')
    end

    it 'returns default error message when missing on failure' do
      response = described_class.new('500', '{}')
      expect(response.message).to eq('Executed with error')
    end
  end

  describe 'accessors' do
    let(:body) do
      {
        'status' => 'successful',
        'message' => 'Credit card statistics',
        'data' => {
          'payment' => { 'successful' => { 'count' => 3 } }
        }
      }
    end

    it 'exposes status, errors, id, stats, http_code, data' do
      response = described_class.new('200', body.to_json)
      expect(response.http_code).to eq('200')
      expect(response.status).to eq('successful')
      expect(response.errors).to be_nil
      expect(response.id).to be_nil
      expect(response.stats).to eq(body['data'])
      expect(response.data).to eq(body)
    end

    it 'exposes id for user create response' do
      response = described_class.new('201', { 'status' => 'successful', 'id' => 'uuid', 'message' => 'Created.' }.to_json)
      expect(response.id).to eq('uuid')
    end

    it 'exposes errors for validation failure' do
      response = described_class.new(
        '422',
        { 'status' => 'failed', 'message' => 'Invalid request parameters', 'errors' => { 'card_pan' => ['is required'] } }.to_json
      )
      expect(response.success?).to eq(false)
      expect(response.errors).to eq('card_pan' => ['is required'])
    end
  end
end
