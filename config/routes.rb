# frozen_string_literal: true

DiscourseMetaDiscover::Engine.routes.draw do
  get "/" => "discover#respond"
  get "/sites" => "discover#index"
  get "/sites/:id" => "discover#show"
  post "/sync" => "discover#sync"
end

Discourse::Application.routes.draw { mount ::DiscourseMetaDiscover::Engine, at: "discover" }
