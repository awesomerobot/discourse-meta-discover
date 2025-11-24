# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::DiscourseMetaDiscover::DiscoverSite do
  describe ".extract_locale_from_tags" do
    it "extracts locale from locale-prefixed tags" do
      tags = %w[locale-en open-source software]
      expect(described_class.extract_locale_from_tags(tags)).to eq("en")
    end

    it "returns nil when no locale tag present" do
      tags = %w[open-source software]
      expect(described_class.extract_locale_from_tags(tags)).to be_nil
    end

    it "returns nil for empty tags" do
      expect(described_class.extract_locale_from_tags([])).to be_nil
    end
  end

  describe ".extract_categories_from_tags" do
    it "excludes locale tags" do
      tags = %w[locale-en open-source software ai]
      expect(described_class.extract_categories_from_tags(tags)).to match_array(
        %w[open-source software ai],
      )
    end

    it "returns empty array for nil tags" do
      expect(described_class.extract_categories_from_tags(nil)).to eq([])
    end
  end

  describe ".sync_from_topic" do
    let(:topic_data) do
      {
        id: 123,
        fancy_title: "Example Discourse Site",
        excerpt: "A great community",
        featured_link: "https://example.com",
        image_url: "https://example.com/logo.png",
        tags: %w[locale-en open-source],
        pinned_at: Time.zone.now,
      }
    end

    it "creates a new site from topic data" do
      expect { described_class.sync_from_topic(topic_data) }.to change {
        described_class.count
      }.by(1)

      site = described_class.last
      expect(site.external_topic_id).to eq(123)
      expect(site.site_name).to eq("Example Discourse Site")
      expect(site.site_url).to eq("https://example.com")
      expect(site.logo_url).to eq("https://example.com/logo.png")
      expect(site.locale).to eq("en")
      expect(site.categories).to include("open-source")
    end

    it "updates existing site on subsequent syncs" do
      described_class.sync_from_topic(topic_data)

      updated_data = topic_data.merge(fancy_title: "Updated Title")
      expect { described_class.sync_from_topic(updated_data) }.not_to change {
        described_class.count
      }

      site = described_class.last
      expect(site.site_name).to eq("Updated Title")
    end

    it "uses title as fallback if fancy_title missing" do
      data = topic_data.merge(fancy_title: nil, title: "Fallback Title")
      described_class.sync_from_topic(data)

      site = described_class.last
      expect(site.site_name).to eq("Fallback Title")
    end

    it "extracts URL from featured_link" do
      described_class.sync_from_topic(topic_data)

      site = described_class.last
      expect(site.site_url).to eq("https://example.com")
    end
  end

  describe "scopes" do
    before do
      described_class.create!(
        external_topic_id: 1,
        site_name: "English Site",
        site_url: "https://en.example.com",
        locale: "en",
        categories: ["open-source"],
      )

      described_class.create!(
        external_topic_id: 2,
        site_name: "German Site",
        site_url: "https://de.example.com",
        locale: "de",
        categories: %w[open-source software],
      )
    end

    it "filters by locale" do
      sites = described_class.by_locale("en")
      expect(sites.count).to eq(1)
      expect(sites.first.site_name).to eq("English Site")
    end

    it "filters by category" do
      sites = described_class.by_category("software")
      expect(sites.count).to eq(1)
      expect(sites.first.site_name).to eq("German Site")
    end
  end
end
