# frozen_string_literal: true

module Jobs
  class SyncDiscoverSitesScheduled < ::Jobs::Scheduled
    every 24.hours

    def execute(args)
      return unless SiteSetting.discover_enabled

      Jobs.enqueue(Jobs::DiscourseMetaDiscover::SyncDiscoverSites)
    end
  end
end
