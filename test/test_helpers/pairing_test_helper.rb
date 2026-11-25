module PairingTestHelper
  def pair_device_as(child)
    child.devices.create!.tap do |device|
      Current.device = device
      cookies[Authentication::COOKIE] = device.plain_token
    end
  end

  # The tap on the confirm screen, then the install view it leads to.
  def pair_with(token)
    post pairing_path, params: {token:}
    follow_redirect! if response.redirect?
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include PairingTestHelper
end
