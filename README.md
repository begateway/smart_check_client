# SmartCheck

Ruby API client for the Smart Check service (beGateway).

## Installation

Add to your application's Gemfile:

```ruby
gem 'smart_check', git: 'git@github.com:begateway/smart_check_client.git'
```

## Usage

### Initialization

```ruby
client = SmartCheck::Client.new(
  url: 'https://smart-check-staging.begateway.com',
  user_id: 'YOUR_SMART_CHECK_USER_ID',
  password: 'YOUR_SMART_CHECK_PASSWORD',
  open_timeout: 5,
  timeout: 10,
  logger: Rails.logger
)
```

`user_id` / `password` are credentials issued by Smart Check administrators
(stored in the `users` table on the Smart Check side) and are used as Basic Auth
on every authenticated route.

### Headers / proxy

```ruby
client = SmartCheck::Client.new(
  url: 'https://smart-check-staging.begateway.com',
  user_id: 'paysage',
  password: 'secret',
  options: { headers: { 'X-Request-Id' => '112233' } }
)

# global proxy (applied to all clients)
SmartCheck::Client.proxy = 'http://proxy.example.com:3128'
```

### API methods

#### Create user — `POST /api/v1/users` (no auth)

```ruby
response = client.create_user(
  username: 'user_test',
  password: 'RSA_ENCRYPTED_BASE64_PASSWORD'
)
response.success? # => true
response.id       # => "a4704d27-073b-41db-996f-44174e0f5f82"
```

#### Create transaction — `POST /api/v1/transactions` (basic auth)

```ruby
response = client.create_transaction(
  id: 'e3b10b9d-7a92-4323-9360-56047d7219c2',
  card_pan: '4200000000000000',
  status: 'successful',
  amount: 10_000,
  currency: 'USD',
  type: 'payment',
  threeds_status: 'successful',
  initial: true,
  created_at: '2023-01-11T14:02:20.449Z'
)
response.success? # => true
```

#### Get transactions statistics — `POST /api/v1/transactions/local` (basic auth)

Statistics within the requesting PSP scope (user_id from Basic Auth).

```ruby
response = client.transactions_local(
  card_pan: '4200000000000000',
  date_from: '2024-01-01T00:00:00Z',
  date_to: '2026-04-22T00:00:00Z',
  types: %w[payment payout capture],
  statuses: %w[successful],
  trx_dates_in_response: true
)
response.success? # => true
response.stats    # => { "payment" => { "successful" => { "count" => ... } }, ... }
```

#### Get transactions statistics — `POST /api/v1/transactions/global` (basic auth)

Statistics across all PSPs.

```ruby
response = client.transactions_global(
  card_pan: '4200000000000000',
  types: %w[payment payout],
  statuses: %w[successful]
)
```

### Response

```ruby
response.http_code # "200"
response.success?  # true if http 2xx and body status == "successful"
response.status    # "successful" / "failed"
response.message   # human-readable message
response.errors    # validation errors hash (only on failure)
response.id        # uuid (only on user create)
response.stats     # statistics object (only on /transactions/local|global)
response.data      # raw parsed body
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that allows experimenting with the gem.
