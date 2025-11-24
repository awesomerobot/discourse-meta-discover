# frozen_string_literal: true

# name: discourse-meta-discover
# about: Fetch and display Discourse sites from discover.discourse.com
# meta_topic_id: TODO
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/discourse-meta-discover
# required_version: 2.7.0

enabled_site_setting :discover_enabled

module ::DiscourseMetaDiscover
  PLUGIN_NAME = "discourse-meta-discover"
  VERSION = "0.0.1"
end

require_relative "lib/discourse_meta_discover/engine"

after_initialize do
  # Auto-sync on first use if enabled and database is empty
  # Only do this if we can acquire a lock to avoid duplicate syncs on multi-server setups
  if SiteSetting.discover_enabled && DiscourseMetaDiscover::DiscoverSite.count == 0
    lock_key = "discourse-meta-discover:auto-sync-check"
    if Discourse.redis.setnx(lock_key, "1")
      Discourse.redis.expire(lock_key, 5.minutes.to_i)

      # Double-check after acquiring lock in case another server already synced
      if DiscourseMetaDiscover::DiscoverSite.count == 0
        Rails.logger.info("DiscoverMetaDiscover: First use detected, enqueuing initial sync...")
        Jobs.enqueue(Jobs::DiscourseMetaDiscover::InitialSyncDiscoverSites)
      end
    end
  end
end
