# frozen_string_literal: true

module DiscourseMetaDiscover
  class DiscoverController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr, only: [:index, :respond]

    PAGE_SIZE = 24

    def respond
      raise Discourse::NotFound unless SiteSetting.discover_enabled

      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          discourse_expires_in 1.minute
          render json: { discover: true }
        end
      end
    end

    def index
      raise Discourse::NotFound unless SiteSetting.discover_enabled

      page = params[:page].to_i
      page = 0 if page < 0

      query = DiscoverSite.all

      # Filter by locale
      if params[:locale].present?
        query = query.by_locale(params[:locale])
      end

      # Filter by category
      if params[:category].present?
        query = query.by_category(params[:category])
      end

      # Search by name
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        query = query.where("site_name ILIKE ?", search_term)
      end

      # Order and paginate
      total_count = query.count
      sites = query.recently_synced.offset(page * PAGE_SIZE).limit(PAGE_SIZE)

      render json: {
               sites: serialize_sites(sites),
               meta: {
                 page: page,
                 per_page: PAGE_SIZE,
                 total: total_count,
                 total_pages: (total_count.to_f / PAGE_SIZE).ceil,
               },
             }
    end

    def show
      raise Discourse::NotFound unless SiteSetting.discover_enabled

      site = DiscoverSite.find(params[:id])
      render json: serialize_site(site)
    rescue ActiveRecord::RecordNotFound
      raise Discourse::NotFound
    end

    def sync
      raise Discourse::InvalidAccess unless current_user&.admin?
      raise Discourse::NotFound unless SiteSetting.discover_enabled

      # Clear cache to force fresh data
      DiscoverApiClient.clear_cache

      # Enqueue sync job
      Jobs.enqueue(Jobs::DiscourseMetaDiscover::SyncDiscoverSites)

      render json: { success: true, message: "Sync job enqueued" }
    end

    private

    def serialize_sites(sites)
      sites.map { |site| serialize_site(site) }
    end

    def serialize_site(site)
      {
        id: site.id,
        external_topic_id: site.external_topic_id,
        site_name: site.site_name,
        site_url: site.site_url,
        description: site.description,
        logo_url: site.logo_url,
        locale: site.locale,
        categories: site.categories,
        tags: site.tags,
        featured: site.featured_at.present?,
        last_synced_at: site.last_synced_at,
      }
    end
  end
end
