# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::Jobs::DiscourseMetaDiscover::SyncDiscoverSites do
  before { SiteSetting.discover_enabled = true }

  describe "#execute" do
    context "when plugin is disabled" do
      before { SiteSetting.discover_enabled = false }

      it "does nothing" do
        expect(::DiscourseMetaDiscover::DiscoverApiClient).not_to receive(:fetch_discover_topics)
        subject.execute({})
      end
    end

    context "when plugin is enabled" do
      it "prevents concurrent syncs" do
        # Simulate a sync in progress
        Discourse.redis.setex("discourse-meta-discover:sync:in_progress", 60, "1")

        expect(::DiscourseMetaDiscover::DiscoverApiClient).not_to receive(:fetch_discover_topics)
        subject.execute({})

        # Clean up
        Discourse.redis.del("discourse-meta-discover:sync:in_progress")
      end

      it "syncs topics from API" do
        mock_topics = [
          {
            id: 123,
            fancy_title: "Test Site",
            excerpt: "A test site",
            featured_link: "https://test.com",
            image_url: "https://test.com/logo.png",
            tags: %w[locale-en technology],
            pinned_at: nil,
          },
        ]

        allow(::DiscourseMetaDiscover::DiscoverApiClient).to receive(:fetch_discover_topics)
          .with(page: 0)
          .and_return(mock_topics)
        allow(::DiscourseMetaDiscover::DiscoverApiClient).to receive(:fetch_discover_topics)
          .with(page: 1)
          .and_return([])

        expect { subject.execute({}) }.to change { ::DiscourseMetaDiscover::DiscoverSite.count }.by(
          1,
        )

        site = ::DiscourseMetaDiscover::DiscoverSite.last
        expect(site.site_name).to eq("Test Site")
        expect(site.site_url).to eq("https://test.com")
      end

      it "handles topic sync errors gracefully" do
        mock_topics = [
          {
            id: 123,
            fancy_title: "Test Site",
            excerpt: "A test site",
            featured_link: "https://test.com",
            tags: %w[locale-en],
            pinned_at: nil,
          },
        ]

        allow(::DiscourseMetaDiscover::DiscoverApiClient).to receive(:fetch_discover_topics)
          .with(page: 0)
          .and_return(mock_topics)
        allow(::DiscourseMetaDiscover::DiscoverApiClient).to receive(:fetch_discover_topics)
          .with(page: 1)
          .and_return([])

        # Make sync_from_topic fail
        allow(::DiscourseMetaDiscover::DiscoverSite).to receive(:sync_from_topic).and_raise(
          StandardError.new("Sync Error"),
        )

        # Should log error but not crash
        expect(Rails.logger).to receive(:error).with(/Failed to sync topic/)

        expect { subject.execute({}) }.not_to raise_error
      end
    end
  end
end
