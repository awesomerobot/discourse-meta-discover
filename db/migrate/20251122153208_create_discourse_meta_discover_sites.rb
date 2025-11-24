# frozen_string_literal: true

class CreateDiscourseMetaDiscoverSites < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_meta_discover_sites do |t|
      t.integer :external_topic_id, null: false
      t.string :site_name, null: false
      t.string :site_url, null: false
      t.text :description
      t.string :logo_url
      t.string :locale, limit: 10
      t.text :categories, array: true, default: []
      t.text :tags, array: true, default: []
      t.datetime :featured_at
      t.datetime :last_synced_at
      t.timestamps
    end

    add_index :discourse_meta_discover_sites, :external_topic_id, unique: true
    add_index :discourse_meta_discover_sites, :locale
    add_index :discourse_meta_discover_sites, :featured_at
  end
end
