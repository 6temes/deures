# Be sure to restart your server when you modify this file.

# Every feature the app does not use is denied. Autoplay is left to this origin: the number pad
# plays its click through an Audio element.
DENIED_BROWSER_FEATURES = %i[
  accelerometer ambient_light_sensor camera display_capture encrypted_media fullscreen geolocation
  gyroscope hid idle_detection keyboard_map magnetometer microphone midi payment
  picture_in_picture screen_wake_lock serial sync_xhr usb web_share
].freeze

# Rails sends this block under the older Feature-Policy header name.
Rails.application.config.permissions_policy do |policy|
  DENIED_BROWSER_FEATURES.each { policy.public_send it, :none }
  policy.autoplay :self
end

# Browsers now read Permissions-Policy, which Rails does not send, so the same list goes out under
# that name too.
Rails.application.config.action_dispatch.default_headers["Permissions-Policy"] =
  DENIED_BROWSER_FEATURES.map { "#{it.to_s.dasherize}=()" }.join(", ")
