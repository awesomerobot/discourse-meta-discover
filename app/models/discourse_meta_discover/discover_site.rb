# frozen_string_literal: true

module DiscourseMetaDiscover
  class DiscoverSite < ActiveRecord::Base
    self.table_name = "discourse_meta_discover_sites"

    validates :external_topic_id, presence: true, uniqueness: true
    validates :site_name, presence: true
    validates :site_url, presence: true

    scope :by_locale, ->(locale) { where(locale: locale) if locale.present? }
    scope :by_category, ->(category) { where("? = ANY(categories)", category) if category.present? }
    scope :recently_synced, -> { order(last_synced_at: :desc) }
    scope :featured, -> { where.not(featured_at: nil).order(featured_at: :desc) }

    def self.sync_from_topic(topic_data)
      site = find_or_initialize_by(external_topic_id: topic_data[:id])

      site.site_name = topic_data[:fancy_title] || topic_data[:title]
      site.site_url = extract_url_from_topic(topic_data)
      site.description = topic_data[:excerpt]
      site.logo_url = extract_image_from_topic(topic_data)
      site.locale = extract_locale_from_tags(topic_data[:tags])
      site.categories = extract_categories_from_tags(topic_data[:tags])
      site.tags = topic_data[:tags] || []
      site.featured_at = topic_data[:pinned_at]
      site.last_synced_at = Time.zone.now

      site.save!
      site
    end

    def self.extract_url_from_topic(topic_data)
      # featured_link is the actual site URL
      topic_data[:featured_link] || topic_data[:url] || topic_data[:slug]
    end

    def self.extract_image_from_topic(topic_data)
      # Use the image_url from the topic (screenshot)
      topic_data[:image_url]
    end

    def self.extract_locale_from_tags(tags)
      return nil if tags.blank?

      locale_tag = tags.find { |tag| tag.start_with?("locale-") }
      locale_tag&.sub("locale-", "")
    end

    def self.extract_categories_from_tags(tags)
      return [] if tags.blank?

      # Filter out locale tags and system tags
      tags.reject { |tag| tag.start_with?("locale-") }
    end
  end
end
