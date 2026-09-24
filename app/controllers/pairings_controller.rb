class PairingsController < ApplicationController
  MANIFEST_TYPE = "application/manifest+json"

  # A signed token is not worth guessing at, so this is about the cost of being asked rather than
  # about the odds: the endpoint is public, unauthenticated and writes a row when it succeeds.
  # Pairing happens a handful of times in an iPad's life, so a limit this high is one no parent
  # reaches. Counting is by address, which behind the tunnel may well be one address for everyone
  # — the ceiling is set so that this stays true either way.
  rate_limit to: 10, within: 1.minute, only: :show

  before_action :no_store
  before_action :set_pairing_link, only: :show

  def show
    return lost_identity unless @pairing_link

    start_pairing_for @pairing_link
    redirect_to root_path if hotwire_native_app?
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
    @pairing_link = PairingLink.find_by_token_for :invitation, params[:token]
    @child = @pairing_link&.child
  end
end
