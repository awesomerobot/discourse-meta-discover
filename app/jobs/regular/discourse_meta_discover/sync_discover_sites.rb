# frozen_string_literal: true

module Jobs
  module DiscourseMetaDiscover
    class SyncDiscoverSites < ::Jobs::Base
      sidekiq_options retry: 3

      def execute(args = {})
        return unless SiteSetting.discover_enabled

        sync_key = "discourse-meta-discover:sync:in_progress"

        # Prevent concurrent syncs
        return if Discourse.redis.get(sync_key).present?

        begin
          # Set lock for 10 minutes
          Discourse.redis.setex(sync_key, 10.minutes.to_i, "1")

          sync_all_pages
        ensure
          Discourse.redis.del(sync_key)
        end
      end

      private

      def sync_all_pages
        page = 0
        total_synced = 0

        loop do
          topics = ::DiscourseMetaDiscover::DiscoverApiClient.fetch_discover_topics(page: page)

          break if topics.blank?

          topics.each do |topic_data|
            sync_topic(topic_data)
            total_synced += 1
          end

          page += 1

          # Don't hit the API too hard - delay between pages
          sleep 1
        end

        Rails.logger.info("DiscoverMetaDiscover: Synced #{total_synced} sites")
      end

      def sync_topic(topic_data)
        ::DiscourseMetaDiscover::DiscoverSite.sync_from_topic(topic_data)
      rescue StandardError => e
        Rails.logger.error(
          "DiscoverMetaDiscover: Failed to sync topic #{topic_data[:id]}: #{e.message}",
        )
      end
    end
  end
end
