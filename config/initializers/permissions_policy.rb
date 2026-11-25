# Be sure to restart your server when you modify this file.

# Every feature the app does not use is denied. Autoplay stays with this origin: the number pad
# plays its click through an Audio element.
Rails.application.config.permissions_policy do |policy|
  policy.accelerometer :none
  policy.ambient_light_sensor :none
  policy.autoplay :self
  policy.camera :none
  policy.display_capture :none
  policy.encrypted_media :none
  policy.fullscreen :none
  policy.geolocation :none
  policy.gyroscope :none
  policy.hid :none
  policy.idle_detection :none
  policy.keyboard_map :none
  policy.magnetometer :none
  policy.microphone :none
  policy.midi :none
  policy.payment :none
  policy.picture_in_picture :none
  policy.screen_wake_lock :none
  policy.serial :none
  policy.sync_xhr :none
  policy.usb :none
  policy.web_share :none
end
