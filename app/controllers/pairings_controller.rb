class PairingsController < ApplicationController
  MANIFEST_TYPE = "application/manifest+json"

  before_action :no_store
  before_action :set_pairing_link, only: :show

  def show
    return lost_identity unless @pairing_link

    start_pairing_for @pairing_link
  end

  # Built here rather than in a template: a manifest is a JSON body, and an ERB view would only
  # be a way of asking for it to be escaped as HTML and then unescaped again with `raw`.
  def manifest
    child = Current.child
    return head :not_found unless child

    render json: {
      name: child.name,
      short_name: child.name,
      start_url: root_path,
      scope: "/",
      display: "standalone",
      theme_color: child.color_hex,
      background_color: child.color_hex,
      icons: [
        {src: helpers.asset_path("icons/#{child.color}-180.png"), sizes: "180x180", type: "image/png"},
        {src: helpers.asset_path("icons/#{child.color}-512.png"), sizes: "512x512", type: "image/png", purpose: "any maskable"}
      ]
    }, content_type: MANIFEST_TYPE
  end

  private

  def lost_identity
    render "shared/lost_identity", status: :not_found
  end

  def set_pairing_link
    link = PairingLink.find_by_token_for :invitation, params[:token]
    return if link.nil? || link.revoked?

    @pairing_link = link
    @child = link.child
  end
end
