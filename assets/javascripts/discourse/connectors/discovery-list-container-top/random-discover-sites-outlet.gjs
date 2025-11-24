import Component from "@glimmer/component";
import RandomDiscoverSites from "../../components/random-discover-sites";

export default class RandomDiscoverSitesOutlet extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.discover_enabled;
  }

  <template>
    <RandomDiscoverSites />
  </template>
}
