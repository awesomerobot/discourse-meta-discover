# Architecture Overview

## Plugin Structure

```
discourse-meta-discover/
├── plugin.rb                          # Plugin entry point
├── config/
│   ├── settings.yml                   # Site settings
│   ├── routes.rb                      # API routes
│   └── locales/
│       ├── server.en.yml             # Server translations
│       └── client.en.yml             # Client translations
├── lib/
│   └── discourse_meta_discover/
│       ├── engine.rb                  # Rails engine
│       └── discover_api_client.rb     # API client for discover.discourse.com
├── app/
│   ├── models/
│   │   └── discourse_meta_discover/
│   │       └── discover_site.rb       # Database model
│   ├── controllers/
│   │   └── discourse_meta_discover/
│   │       └── discover_controller.rb # REST API controller
│   └── jobs/
│       ├── regular/
│       │   └── discourse_meta_discover/
│       │       ├── sync_discover_sites.rb    # Manual/on-demand sync
│       │       └── initial_sync_discover_sites.rb  # Auto-triggered initial sync
│       └── scheduled/
│           └── sync_discover_sites_scheduled.rb  # Scheduled sync (24 hours)
├── assets/
│   ├── javascripts/
│   │   └── discourse/
│   │       ├── components/
│   │       │   └── random-discover-sites.gjs      # Random sites component
│   │       ├── connectors/
│   │       │   └── discovery-list-container-top/
│   │       │       └── random-discover-sites-outlet.gjs  # Homepage connector
│   │       └── templates/
│   │           └── discover.gjs                   # Discover page template
│   └── stylesheets/
│       └── random-discover-sites.scss             # Component styles
├── db/
│   └── migrate/
│       └── 20251122153208_create_discourse_meta_discover_sites.rb
└── spec/
    ├── models/
    │   └── discourse_meta_discover/
    │       └── discover_site_spec.rb
    ├── requests/
    │   └── discourse_meta_discover/
    │       └── discover_controller_spec.rb
    └── jobs/
        ├── regular/
        │   └── discourse_meta_discover/
        │       └── sync_discover_sites_spec.rb
        └── scheduled/
            └── sync_discover_sites_scheduled_spec.rb
```

## Data Flow

```
discover.discourse.com
        ↓
[DiscoverApiClient]
        ↓
    (Redis Cache - 5min/1hr)
        ↓
[SyncDiscoverSites Job]
        ↓
    (Process & Parse)
        ↓
[DiscoverSite Model]
        ↓
   (PostgreSQL)
        ↓
[DiscoverController]
        ↓
    REST API
        ↓
   Frontend/Consumers
```

## Components

### 1. API Client (`lib/discover_api_client.rb`)
- Fetches topic lists from discover.discourse.com
- Redis caching with 5 minute TTL for topic lists
- Uses Excon for HTTP requests with exponential backoff for rate limiting
- Handles authentication if API key provided
- Optimized: fetches only topic list data (no individual topic detail calls)

### 2. Database Model (`app/models/discover_site.rb`)
- Stores cached site data
- Fields:
  - `external_topic_id` - Topic ID from discover.discourse.com
  - `site_name` - From topic `fancy_title` or `title`
  - `site_url` - From topic `featured_link`
  - `description` - From topic excerpt
  - `logo_url` - From topic `image_url`
  - `locale` - Extracted from `locale-*` tags
  - `categories` - Extracted from non-locale tags
  - `tags` - All topic tags
  - `featured_at` - Pinned status
  - `last_synced_at` - Sync timestamp
- Scopes for filtering: `by_locale`, `by_category`, `featured`

### 3. Sync Jobs
**Regular Job** (`sync_discover_sites.rb`):
- Fetches all topics from discover category (no pagination limit)
- Syncs directly from topic list data (optimized to avoid N+1 queries)
- Parses and stores in database
- Prevents concurrent syncs with Redis lock (10 minute duration)
- Rate limiting with 1 second delay between pages

**Initial Sync Job** (`initial_sync_discover_sites.rb`):
- Auto-triggered when database is empty
- Same behavior as regular sync job

**Scheduled Job** (`sync_discover_sites_scheduled.rb`):
- Runs every 24 hours
- Enqueues regular sync job

### 4. Controller (`discover_controller.rb`)
**Endpoints**:
- `GET /discover` - HTML/JSON route for discover page
- `GET /discover/sites.json` - List sites with filtering
- `GET /discover/sites/:id.json` - Single site details
- `POST /discover/sync.json` - Manual sync (admin only)

**Features**:
- Pagination (24 per page)
- Filtering by locale, category, search
- JSON serialization
- 1 minute cache headers for API responses

## Caching Strategy

### Two-Tier Caching:

1. **Redis (API Level)**
   - Topic lists: 5 minutes
   - Key pattern: `discourse-meta-discover:*`
   - Sync lock to prevent concurrent syncs (10 minute duration)
   - Lock key: `discourse-meta-discover:sync:in_progress`

2. **PostgreSQL (Database)**
   - Persistent storage for all site data
   - Updated on sync (every 24 hours or manual trigger)
   - Indexed on `external_topic_id`, `locale`, `featured_at`
   - Enables fast filtering and pagination

## Configuration

### Site Settings (`config/settings.yml`)
- `discover_enabled` - Enable/disable plugin (default: false)
- `discover_api_url` - Source URL (default: https://discover.discourse.com)
- `discover_api_key` - Optional API key for authentication (helps avoid rate limiting)
- `discover_api_username` - API username (default: system)
- `discover_category_slug` - Category slug to fetch sites from (default: discover)
- `discover_category_id` - Category ID to fetch sites from (default: 5)

## Frontend Components

### Random Sites Component (`assets/javascripts/discourse/components/random-discover-sites.gjs`)
- Displays 5 random English-language sites
- Fetches from a random page of results for true randomization
- Includes refresh button to load new sites
- Shows site logo, name, description, locale, and categories
- Links open in new tab with proper security attributes

### Plugin Outlet Connector (`assets/javascripts/discourse/connectors/discovery-list-container-top/random-discover-sites-outlet.gjs`)
- Injects random sites component into homepage
- Uses `shouldRender` pattern to respect `discover_enabled` setting
- Positioned at top of discovery list container

### Discover Route Template (`assets/javascripts/discourse/templates/discover.gjs`)
- Full page view for browsing all discover sites
- Available at `/discover` when plugin is enabled

## Extension Points

### For Theme Components:
```javascript
// Fetch sites
fetch('/discover/sites.json?locale=en&category=open-source')
  .then(r => r.json())
  .then(data => {
    // Render sites
  });
```

### For Other Plugins:
```ruby
# Access model
sites = DiscourseMetaDiscover::DiscoverSite.by_locale('en')

# Trigger sync
Jobs.enqueue(Jobs::DiscourseMetaDiscover::SyncDiscoverSites)

# Access API client
DiscourseMetaDiscover::DiscoverApiClient.fetch_discover_topics
```

## Performance Considerations

- **Optimized API Usage**: Eliminated N+1 queries by syncing directly from topic lists (~50 API calls for 1000+ sites instead of 1500+)
- **Redis Caching**: Reduces API calls to discover.discourse.com (5 minute TTL)
- **Database Indexes**: On frequently queried fields (`external_topic_id`, `locale`, `featured_at`)
- **Pagination**: Limits data transfer (24 per page)
- **Sync Lock**: Prevents concurrent syncs and thundering herd
- **Rate Limiting**: 1 second delay between pages, exponential backoff on 429 errors
- **Fixed Sync Interval**: 24 hours between automatic syncs
- **Efficient Data Extraction**: Direct field mapping from topic data (no additional API calls)

## Security

- Admin-only manual sync endpoint
- Optional API key authentication
- Input validation on all parameters
- XSS protection via JSON API
- CSRF protection via Discourse defaults
