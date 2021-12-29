module Agents
  class CoinmarketcapAgent < Agent
    include FormConfigurable

    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Coinmarketcap Agent checks rank and can create events if there is a change.

      `debug` is used to verbose mode.

      `action` is the wanted action, like checking token rank.

      `token` is the id of the token.

      `api_key` is needed for auth.

      `changes_only` is only used to emit event about an event's change.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "status": {
              "timestamp": "2021-12-29T09:24:12.666Z",
              "error_code": 0,
              "error_message": null,
              "elapsed": 28,
              "credit_count": 1,
              "notice": null
            },
            "data": {
              "1697": {
                "id": 1697,
                "name": "Basic Attention Token",
                "symbol": "BAT",
                "slug": "basic-attention-token",
                "num_market_pairs": 244,
                "date_added": "2017-06-01T00:00:00.000Z",
                "tags": [
                  "marketing",
                  "content-creation",
                  "defi",
                  "payments",
                  "binance-smart-chain",
                  "dcg-portfolio",
                  "1confirmation-portfolio",
                  "pantera-capital-portfolio",
                  "web3"
                ],
                "max_supply": 1500000000,
                "circulating_supply": 1493865018.4473505,
                "total_supply": 1500000000,
                "platform": {
                  "id": 1027,
                  "name": "Ethereum",
                  "symbol": "ETH",
                  "slug": "ethereum",
                  "token_address": "0x0d8775f648430679a709e98d2b0cb6250d2887ef"
                },
                "is_active": 1,
                "cmc_rank": 71,
                "is_fiat": 0,
                "last_updated": "2021-12-29T09:23:09.000Z",
                "quote": {
                  "USD": {
                    "price": 1.1981546955807796,
                    "volume_24h": 292305456.1489774,
                    "volume_change_24h": -22.7985,
                    "percent_change_1h": -1.45132346,
                    "percent_change_24h": -8.53447767,
                    "percent_change_7d": -0.30962906,
                    "percent_change_30d": -25.57747572,
                    "percent_change_60d": 48.17017438,
                    "percent_change_90d": 96.606884,
                    "market_cap": 1789881386.416561,
                    "market_cap_dominance": 0.0801,
                    "fully_diluted_market_cap": 1797232043.37,
                    "last_updated": "2021-12-29T09:23:09.000Z"
                  }
                }
              }
            }
          }
    MD

    def default_options
      {
        'api_key' => '',
        'action' => 'rank',
        'token' => '',
        'debug' => 'false'
      }
    end

    form_configurable :api_key, type: :string
    form_configurable :action, type: :array, values: ['rank']
    form_configurable :token, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean
    def validate_options

      unless options['token'].present?
        errors.add(:base, "token is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end
    end

    def working?
      !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def get_rank(token)
      uri = URI.parse("https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?id=#{token}")
      request = Net::HTTP::Get.new(uri)
      request["X-Cmc_pro_api_key"] = "#{interpolated['api_key']}"
      request["Accept"] = "application/json"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log "request status : #{response.code}"

      if interpolated['debug'] == 'true'
        log "response.body"
        log response.body
      end
      return response.body
    end

    def fetch
      case interpolated['action']
      when "rank"
        payload = JSON.parse(get_rank(interpolated['token']))
        if interpolated['changes_only'] == 'true'
          if payload.to_s != memory['last_status']
            if !memory['last_status'].nil?
              last_status = JSON.parse(memory['last_status'].gsub("=>", ": ").gsub(": nil", ": null"))
            end
            if interpolated['debug'] == 'true'
              log "payload rank = #{payload['data']["#{interpolated['token']}"]['cmc_rank']}"
              if !memory['last_status'].nil?
                log "last status rank =  #{last_status['data']["#{interpolated['token']}"]['cmc_rank']}"
              end
            end
            if !memory['last_status'].nil?
              if payload['data']["#{interpolated['token']}"]['cmc_rank'] != last_status['data']["#{interpolated['token']}"]['cmc_rank']
                create_event payload: payload
              end
            else
                create_event payload: payload
            end
            memory['last_status'] = payload.to_s
          end
        else
          create_event payload: payload
          if payload.to_s != memory['last_status']
            memory['last_status'] = payload.to_s
          end
        end
      end
    end
  end
end
