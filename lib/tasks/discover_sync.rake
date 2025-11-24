# frozen_string_literal: true

desc "Sync all sites from discover.discourse.com (one-time full sync)"
task "discover:full_sync" => :environment do
  unless SiteSetting.discover_enabled
    puts "Error: discover_enabled is false. Enable it first."
    exit 1
  end

  puts "Starting full sync from discover.discourse.com..."
  puts "This will fetch ALL pages with delays to avoid rate limiting."

  page = 0
  total_synced = 0
  delay_between_pages = 2 # 2 seconds between pages to be safe

  loop do
    puts "\n--- Fetching page #{page} ---"

    topics = DiscourseMetaDiscover::DiscoverApiClient.fetch_discover_topics(page: page)

    if topics.blank?
      puts "No more topics found. Stopping."
      break
    end

    puts "Found #{topics.count} topics on page #{page}"

    topics.each_with_index do |topic_data, index|
      begin
        site = DiscourseMetaDiscover::DiscoverSite.sync_from_topic(topic_data)
        total_synced += 1
        print "."
      rescue StandardError => e
        puts "\nError syncing topic #{topic_data[:id]}: #{e.message}"
        print "x"
      end
    end

    page += 1

    puts "\n✓ Page #{page - 1} complete. Total synced: #{total_synced}"

    # Delay between pages
    if topics.count == 30 # More pages likely exist
      puts "Waiting #{delay_between_pages} seconds before next page..."
      sleep delay_between_pages
    else
      puts "Last page (< 30 topics). Stopping."
      break
    end
  end

  puts "\n" + "=" * 50
  puts "✓ Full sync complete!"
  puts "Total sites synced: #{total_synced}"
  puts "Total sites in database: #{DiscourseMetaDiscover::DiscoverSite.count}"
  puts "=" * 50
end

desc "Clear all synced discover sites"
task "discover:clear" => :environment do
  count = DiscourseMetaDiscover::DiscoverSite.count
  print "Are you sure you want to delete #{count} sites? (y/N): "

  response = STDIN.gets.chomp
  if response.downcase == 'y'
    DiscourseMetaDiscover::DiscoverSite.delete_all
    DiscourseMetaDiscover::DiscoverApiClient.clear_cache
    puts "✓ All sites deleted and cache cleared."
  else
    puts "Cancelled."
  end
end
