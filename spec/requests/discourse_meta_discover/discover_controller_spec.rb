# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::DiscourseMetaDiscover::DiscoverController do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  before { SiteSetting.discover_enabled = true }

  describe "#respond" do
    context "when plugin is disabled" do
      before { SiteSetting.discover_enabled = false }

      it "returns 404" do
        get "/discover"
        expect(response.status).to eq(404)
      end
    end

    context "when plugin is enabled" do
      it "returns HTML for browser requests" do
        get "/discover"
        expect(response.status).to eq(200)
        expect(response.content_type).to include("text/html")
      end

      it "returns JSON for API requests" do
        get "/discover", params: {}, headers: { "Accept" => "application/json" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["discover"]).to eq(true)
      end
    end
  end

  describe "#index" do
    let!(:site1) do
      ::DiscourseMetaDiscover::DiscoverSite.create!(
        external_topic_id: 1,
        site_name: "Test Site 1",
        site_url: "https://test1.com",
        locale: "en",
        categories: ["technology"],
        last_synced_at: 1.hour.ago,
      )
    end

    let!(:site2) do
      ::DiscourseMetaDiscover::DiscoverSite.create!(
        external_topic_id: 2,
        site_name: "Test Site 2",
        site_url: "https://test2.com",
        locale: "de",
        categories: ["software"],
        last_synced_at: 2.hours.ago,
      )
    end

    context "when plugin is disabled" do
      before { SiteSetting.discover_enabled = false }

      it "returns 404" do
        get "/discover/sites.json"
        expect(response.status).to eq(404)
      end
    end

    context "when plugin is enabled" do
      it "returns all sites" do
        get "/discover/sites.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["sites"].length).to eq(2)
        expect(json["meta"]["total"]).to eq(2)
      end

      it "filters by locale" do
        get "/discover/sites.json", params: { locale: "en" }
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["sites"].length).to eq(1)
        expect(json["sites"][0]["site_name"]).to eq("Test Site 1")
      end

      it "filters by category" do
        get "/discover/sites.json", params: { category: "software" }
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["sites"].length).to eq(1)
        expect(json["sites"][0]["site_name"]).to eq("Test Site 2")
      end

      it "searches by name" do
        get "/discover/sites.json", params: { search: "Site 1" }
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["sites"].length).to eq(1)
        expect(json["sites"][0]["site_name"]).to eq("Test Site 1")
      end

      it "paginates results" do
        get "/discover/sites.json", params: { page: 0 }
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["meta"]["page"]).to eq(0)
        expect(json["meta"]["per_page"]).to eq(24)
      end
    end
  end

  describe "#show" do
    let!(:site) do
      ::DiscourseMetaDiscover::DiscoverSite.create!(
        external_topic_id: 1,
        site_name: "Test Site",
        site_url: "https://test.com",
      )
    end

    context "when plugin is disabled" do
      before { SiteSetting.discover_enabled = false }

      it "returns 404" do
        get "/discover/sites/#{site.id}.json"
        expect(response.status).to eq(404)
      end
    end

    context "when plugin is enabled" do
      it "returns the site" do
        get "/discover/sites/#{site.id}.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["site_name"]).to eq("Test Site")
        expect(json["site_url"]).to eq("https://test.com")
      end

      it "returns 404 for non-existent site" do
        get "/discover/sites/999999.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#sync" do
    context "when not logged in" do
      it "returns 403" do
        post "/discover/sync.json"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in as regular user" do
      before { sign_in(user) }

      it "returns 403" do
        post "/discover/sync.json"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      context "when plugin is disabled" do
        before { SiteSetting.discover_enabled = false }

        it "returns 404" do
          post "/discover/sync.json"
          expect(response.status).to eq(404)
        end
      end

      context "when plugin is enabled" do
        it "enqueues sync job" do
          expect { post "/discover/sync.json" }.to change {
            ::Jobs::DiscourseMetaDiscover::SyncDiscoverSites.jobs.size
          }.by(1)

          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["success"]).to eq(true)
        end
      end
    end
  end
end
