# frozen_string_literal: true

require "rails_helper"

describe "discourse-meta-discover" do
  it "loads plugin" do
    expect(defined?(DiscourseMetaDiscover)).to be_truthy
    expect(DiscourseMetaDiscover::PLUGIN_NAME).to eq("discourse-meta-discover")
  end
end
