# Discourse Meta Discover Plugin

Fetch and display Discourse sites from discover.discourse.com on your Discourse instance.

## Features

- Automatically sync sites from discover.discourse.com
- Cache site data in PostgreSQL with Redis caching
- Filter by locale (en, de, intl, etc.)
- Filter by categories (open-source, software, ai, technology, etc.)
- Search by site name
- REST API for flexible integration
- Background job syncing every 24 hours
- Display random sites component on homepage
- Dedicated `/discover` route to browse all sites
- Optimized with exponential backoff for rate limiting

## Installation

Add the plugin to your `app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/discourse-meta-discover.git
```

Rebuild your container:

```bash
cd /var/discourse
./launcher rebuild app
```

## Configuration

Navigate to Admin → Settings → Plugins → discourse-meta-discover

### Site Settings

- `discover_enabled` - Enable/disable the plugin (default: false)
- `discover_api_url` - Source Discourse URL (default: https://discover.discourse.com)
- `discover_api_key` - API key for authentication (optional, helps avoid rate limiting)
- `discover_api_username` - API username (default: system)
- `discover_category_slug` - Category slug to fetch sites from (default: discover)
- `discover_category_id` - Category ID to fetch sites from (default: 5)

## API Endpoints

### List Sites
```
GET /discover/sites.json
```

Query parameters:
- `page` - Page number (default: 0)
- `locale` - Filter by locale (e.g., "en", "de")
- `category` - Filter by category tag (e.g., "open-source", "software")
- `search` - Search by site name

Response:
```json
{
  "sites": [...],
  "meta": {
    "page": 0,
    "per_page": 24,
    "total": 100,
    "total_pages": 5
  }
}
```

### Get Site Details
```
GET /discover/sites/:id.json
```

### Manual Sync (Admin Only)
```
POST /discover/sync.json
```

## Usage

### Via API

```javascript
// Fetch all sites
fetch('/discover/sites.json')
  .then(r => r.json())
  .then(data => console.log(data.sites));

// Filter by locale
fetch('/discover/sites.json?locale=en')
  .then(r => r.json())
  .then(data => console.log(data.sites));

// Filter by category
fetch('/discover/sites.json?category=open-source')
  .then(r => r.json())
  .then(data => console.log(data.sites));
```

### Manual Sync

As an admin, you can manually trigger a sync:

```javascript
fetch('/discover/sync.json', { method: 'POST' })
  .then(r => r.json())
  .then(data => console.log(data));
```

Or via Rails console:
```ruby
Jobs.enqueue(Jobs::DiscourseMetaDiscover::SyncDiscoverSites)
```

## Frontend Components

The plugin includes:
- **Random Sites Component** - Displays 5 random English-language sites on the homepage
- **Discover Page** - Browse all sites at `/discover`
- Refresh button to load different random sites

## Architecture

- **API Client** (`lib/discourse_meta_discover/discover_api_client.rb`) - Handles communication with discover.discourse.com with exponential backoff
- **Model** (`app/models/discourse_meta_discover/discover_site.rb`) - Database model for cached sites
- **Jobs** - Background syncing with scheduled job (runs every 24 hours)
  - `SyncDiscoverSites` - Regular sync job
  - `InitialSyncDiscoverSites` - Initial sync on first use
  - `SyncDiscoverSitesScheduled` - Scheduled job
- **Controller** (`app/controllers/discourse_meta_discover/discover_controller.rb`) - REST API endpoints
- **Caching** - Two-tier caching (Redis for API responses + PostgreSQL for persistent storage)

## License

MIT
