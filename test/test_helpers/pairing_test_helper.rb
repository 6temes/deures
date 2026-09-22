module PairingTestHelper
  def pair_device_as(child)
    child.devices.create!.tap do |device|
      Current.device = device
      cookies[Authentication::COOKIE] = device.plain_token
    end
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include PairingTestHelper
end
