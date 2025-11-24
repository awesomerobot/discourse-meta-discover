# Testing Guide

## Setup

1. Enable the plugin in Admin → Settings:
   - Set `discover_enabled` to `true`
   - Configure `discover_api_url` (default: https://discover.discourse.com)
   - Set `discover_category_id` to the category containing discover sites
   - Optionally configure `discover_api_key` and `discover_api_username` for authenticated requests

2. Run the database migration:
   ```bash
   cd /var/discourse
   ./launcher enter app
   rake db:migrate
   ```

## Manual Testing

### 1. Trigger Manual Sync

As an admin, trigger a manual sync:

```bash
curl -X POST http://localhost:3000/discover/sync.json \
  -H "Api-Key: YOUR_API_KEY" \
  -H "Api-Username: YOUR_USERNAME"
```

Or via Rails console:
```ruby
Jobs.enqueue(Jobs::DiscourseMetaDiscover::SyncDiscoverSites)
```

### 2. Check Database

```ruby
# Rails console
DiscourseMetaDiscover::DiscoverSite.count
DiscourseMetaDiscover::DiscoverSite.first
DiscourseMetaDiscover::DiscoverSite.by_locale('en').count
```

### 3. Test API Endpoints

```bash
# List all sites
curl http://localhost:3000/discover/sites.json

# Filter by locale
curl http://localhost:3000/discover/sites.json?locale=en

# Filter by category
curl http://localhost:3000/discover/sites.json?category=open-source

# Search
curl http://localhost:3000/discover/sites.json?search=discourse

# Pagination
curl http://localhost:3000/discover/sites.json?page=1

# Get specific site
curl http://localhost:3000/discover/sites/1.json
```

### 4. Test Scheduled Job

Check if the scheduled job is running:

```ruby
# Rails console
Jobs::SyncDiscoverSitesScheduled.new.execute({})
```

### 5. Test Caching

```ruby
# Rails console

# Check Redis cache
Discourse.redis.keys("discourse-meta-discover:*")

# Clear cache
DiscourseMetaDiscover::DiscoverApiClient.clear_cache
```

## Development Testing

### Run specs (when implemented)

```bash
bundle exec rspec plugins/discourse-meta-discover
```

### Debug API calls

```ruby
# Rails console
DiscourseMetaDiscover::DiscoverApiClient.fetch_discover_topics(page: 0)
DiscourseMetaDiscover::DiscoverApiClient.fetch_topic_details(123)
```

## Expected Data Structure

After syncing, each site should have:
- `site_name` - Name of the Discourse site
- `site_url` - URL to the site
- `description` - Excerpt from the topic
- `locale` - Extracted from tags (e.g., "en" from "locale-en")
- `categories` - Array of category tags
- `tags` - All topic tags
- `featured_at` - If the topic is pinned
- `last_synced_at` - Timestamp of last sync

## Troubleshooting

### No sites showing up

1. Check if sync job ran:
   ```ruby
   Jobs.enqueue(Jobs::DiscourseMetaDiscover::SyncDiscoverSites)
   ```

2. Check logs:
   ```bash
   tail -f /var/discourse/shared/standalone/log/rails/production.log | grep Discover
   ```

3. Verify API connection:
   ```ruby
   DiscourseMetaDiscover::DiscoverApiClient.fetch_discover_topics(page: 0)
   ```

### Cache issues

Clear all caches:
```ruby
DiscourseMetaDiscover::DiscoverApiClient.clear_cache
Discourse.redis.flushdb # WARNING: Clears all Redis data
```
