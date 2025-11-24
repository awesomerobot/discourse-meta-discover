# frozen_string_literal: true

module DiscourseMetaDiscover
  class DiscoverApiClient
    CACHE_KEY_PREFIX = "discourse-meta-discover"
    MAX_RETRIES = 3
    BASE_RETRY_DELAY = 2 # seconds

    class << self
      def fetch_discover_topics(page: 0)
        return [] unless SiteSetting.discover_enabled

        category_slug = SiteSetting.discover_category_slug
        category_id = SiteSetting.discover_category_id
        url = "#{api_base_url}/c/#{category_slug}/#{category_id}.json"

        cache_key = "#{CACHE_KEY_PREFIX}:topics:page:#{page}"

        # Check cache first (5 minute cache for pagination)
        cached = Discourse.redis.get(cache_key)
        if cached.present?
          return JSON.parse(cached, symbolize_names: true)
        end

        response = make_request(:get, url, params: { page: page })
        return [] unless response

        topics = response.dig(:topic_list, :topics) || []

        # Cache the response
        Discourse.redis.setex(cache_key, 5.minutes.to_i, topics.to_json)

        topics
      rescue StandardError => e
        Rails.logger.error("DiscoverApiClient: Failed to fetch topics: #{e.message}")
        []
      end

      def clear_cache
        pattern = "#{CACHE_KEY_PREFIX}:*"
        keys = Discourse.redis.scan_each(match: pattern).to_a
        Discourse.redis.del(keys) if keys.any?
      end

      private

      def make_request(method, url, params: {}, retry_count: 0)
        headers = {
          "Accept" => "application/json",
          "User-Agent" => "DiscourseMetaDiscover/#{DiscourseMetaDiscover::VERSION}",
        }

        # Add API authentication if configured
        if SiteSetting.discover_api_key.present?
          headers["Api-Key"] = SiteSetting.discover_api_key
          headers["Api-Username"] = SiteSetting.discover_api_username
        end

        response = Excon.public_send(
          method,
          url,
          {
            headers: headers,
            query: params,
            omit_default_port: true,
            read_timeout: 10,
            connect_timeout: 5,
          },
        )

        if response.status == 200
          JSON.parse(response.body, symbolize_names: true)
        elsif response.status == 429 && retry_count < MAX_RETRIES
          # Rate limited - retry with exponential backoff
          retry_after = extract_retry_after(response.headers)
          delay = retry_after || (BASE_RETRY_DELAY * (2**retry_count))

          Rails.logger.warn(
            "DiscoverApiClient: Rate limited (429). Retrying in #{delay}s (attempt #{retry_count + 1}/#{MAX_RETRIES})",
          )

          sleep delay
          make_request(method, url, params: params, retry_count: retry_count + 1)
        else
          Rails.logger.warn("DiscoverApiClient: Request to #{url} returned status #{response.status}")
          nil
        end
      rescue Excon::Error => e
        Rails.logger.error("DiscoverApiClient: HTTP error: #{e.message}")
        nil
      rescue JSON::ParserError => e
        Rails.logger.error("DiscoverApiClient: JSON parse error: #{e.message}")
        nil
      end

      def extract_retry_after(headers)
        # Check for Retry-After header (can be seconds or HTTP date)
        retry_after = headers["Retry-After"]
        return nil unless retry_after

        # Try parsing as integer (seconds)
        Integer(retry_after)
      rescue ArgumentError
        # If not an integer, might be HTTP date - ignore for simplicity
        nil
      end

      def api_base_url
        SiteSetting.discover_api_url.chomp("/")
      end
    end
  end
end
