import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import LoadMore from "discourse/components/load-more";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";

export default class DiscoverSitesList extends Component {
  @tracked sites = [];
  @tracked loading = true;
  @tracked loadingMore = false;
  @tracked page = 0;
  @tracked totalPages = 1;

  constructor() {
    super(...arguments);
    this.loadSites();
  }

  get canLoadMore() {
    return this.page < this.totalPages - 1;
  }

  @action
  async loadSites() {
    const isInitialLoad = this.sites.length === 0;

    if (isInitialLoad) {
      this.loading = true;
    } else {
      this.loadingMore = true;
    }

    try {
      const response = await ajax(`/discover/sites.json?page=${this.page}`);
      this.sites = [...this.sites, ...(response.sites || [])];
      this.totalPages = response.meta.total_pages;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
      this.loadingMore = false;
    }
  }

  @action
  async loadMore() {
    if (this.canLoadMore && !this.loadingMore) {
      this.page += 1;
      await this.loadSites();
    }
  }

  <template>
    <div class="discover-sites-list">
      <div class="discover-header">
        <h1>Discover Discourse Sites</h1>
        <p class="discover-subtitle">
          Explore communities powered by Discourse
        </p>
      </div>

      <ConditionalLoadingSpinner @condition={{this.loading}}>
        <LoadMore
          @action={{this.loadMore}}
          @enabled={{this.canLoadMore}}
          @isLoading={{this.loadingMore}}
        >
          <div class="discover-sites-grid">
            {{#each this.sites as |site|}}
              <div class="discover-site-card">
                {{#if site.logo_url}}
                  <a
                    href={{site.site_url}}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <img
                      src={{site.logo_url}}
                      alt={{site.site_name}}
                      class="discover-site-screenshot"
                    />
                  </a>
                {{/if}}

                <div class="discover-site-info">
                  <h4>
                    <a
                      href={{site.site_url}}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      {{site.site_name}}
                    </a>
                  </h4>

                  {{#if site.description}}
                    <p class="discover-site-description">{{site.description}}</p>
                  {{/if}}

                  <div class="discover-site-meta">
                    {{#if site.locale}}
                      <span class="discover-locale">{{site.locale}}</span>
                    {{/if}}
                    {{#each site.categories as |category|}}
                      <span class="discover-category">{{category}}</span>
                    {{/each}}
                  </div>
                </div>
              </div>
            {{/each}}
          </div>

          <ConditionalLoadingSpinner @condition={{this.loadingMore}} />
        </LoadMore>
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
