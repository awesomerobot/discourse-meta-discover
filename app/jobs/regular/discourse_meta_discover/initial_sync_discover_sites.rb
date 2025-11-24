# frozen_string_literal: true

module Jobs
  module DiscourseMetaDiscover
    class InitialSyncDiscoverSites < ::Jobs::Base
      sidekiq_options retry: 1

      def execute(args = {})
        return unless SiteSetting.discover_enabled

        sync_key = "discourse-meta-discover:initial-sync:in_progress"

        # Prevent concurrent initial syncs
        return if Discourse.redis.get(sync_key).present?

        begin
          # Set lock for 1 hour
          Discourse.redis.setex(sync_key, 1.hour.to_i, "1")

          sync_all_pages
        ensure
          Discourse.redis.del(sync_key)
        end
      end

      private

      def sync_all_pages
        page = 0
        total_synced = 0

        Rails.logger.info("DiscoverMetaDiscover: Starting initial sync...")

        loop do
          topics = ::DiscourseMetaDiscover::DiscoverApiClient.fetch_discover_topics(page: page)

          break if topics.blank?

          topics.each do |topic_data|
            sync_topic(topic_data)
            total_synced += 1
          end

          page += 1

          # Delay between pages to avoid rate limiting
          sleep 1
        end

        Rails.logger.info("DiscoverMetaDiscover: Initial sync complete! Synced #{total_synced} sites")
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
