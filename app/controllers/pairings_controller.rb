class PairingsController < ApplicationController
  # One checked-in icon per color in Child::COLORS, read once at boot: nothing then builds a
  # file path out of a column an agent operation can write.
  ICONS = Child::COLORS.keys.index_with { Rails.root.join("app/assets/images/icons/#{it}-180.png").binread }.freeze
  ICONS_512 = Child::COLORS.keys.index_with { Rails.root.join("app/assets/images/icons/#{it}-512.png").binread }.freeze
  LAUNCH = {launch: "1"}.freeze
  MANIFEST_TYPE = "application/manifest+json"

  # The device cookie is resolved here as on any other request, rather than skipped with
  # allow_unauthenticated_access, because the installed icon replays this path on every launch and
  # the device it already resolves to is the one to reuse; skipping it grows a device row a launch.
  before_action :no_store
  before_action :set_pairing_link

  helper_method :launch_url

  def show
    return lost_identity unless @pairing_link

    pair_device
    return redirect_to "/" if launched?

    render :show
  end

  # Built here rather than in a template: a manifest is a JSON body, and an ERB view would only
  # be a way of asking for it to be escaped as HTML and then unescaped again with `raw`.
  def manifest
    return head :not_found unless @pairing_link

    render json: {
      name: @child.name,
      short_name: @child.name,
      start_url: launch_url,
      scope: "/",
      display: "standalone",
      theme_color: @child.color_hex,
      background_color: @child.color_hex,
      icons: [
        {src: pairing_icon_path(@token), sizes: "180x180", type: "image/png"},
        {src: pairing_icon_512_path(@token), sizes: "512x512", type: "image/png", purpose: "any maskable"}
      ]
    }, content_type: MANIFEST_TYPE
  end

  def icon
    return head :not_found unless @pairing_link

    send_data ICONS.fetch(@child.color), type: "image/png", disposition: "inline"
  end

  def icon_512
    return head :not_found unless @pairing_link

    send_data ICONS_512.fetch(@child.color), type: "image/png", disposition: "inline"
  end

  private

  def launched?
    params[:launch].present?
  end

  def launch_url
    pairing_path @token, **LAUNCH
  end

  def lost_identity
    render "shared/lost_identity", status: :not_found
  end

  def pair_device
    return if Current.device&.pairing_link_id == @pairing_link.id

    start_pairing_for @pairing_link
  end

  def set_pairing_link
    link = PairingLink.find_by_token params[:token]
    return if link.nil? || link.revoked?

    @pairing_link = link
    @child = link.child
    @token = params[:token]
  end
end
