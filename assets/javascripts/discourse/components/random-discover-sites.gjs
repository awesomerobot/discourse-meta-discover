import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/components/d-button";

export default class RandomDiscoverSites extends Component {
  @tracked sites = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.loadRandomSites();
  }

  @action
  async loadRandomSites() {
    this.loading = true;
    try {
      const response = await ajax("/discover/sites.json?locale=en");
      const totalPages = response.meta.total_pages;

      // Pick a random page
      const randomPage = Math.floor(Math.random() * totalPages);
      const pageResponse = await ajax(`/discover/sites.json?locale=en&page=${randomPage}`);

      // Get 5 random sites from that page
      const allSites = pageResponse.sites || [];
      this.sites = this.getRandomItems(allSites, Math.min(5, allSites.length));
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  getRandomItems(array, count) {
    const shuffled = [...array].sort(() => 0.5 - Math.random());
    return shuffled.slice(0, count);
  }

  <template>
    <div class="random-discover-sites">
      <div class="random-discover-header">
        <h3>Discover Discourse Sites</h3>
        <DButton
          @action={{this.loadRandomSites}}
          @label="discover.refresh"
          @icon="sync"
          class="btn-small"
        />
      </div>

      {{#if this.loading}}
        <div class="spinner small"></div>
      {{else}}
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
      {{/if}}
    </div>
  </template>
}
