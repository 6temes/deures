module Authentication
  extend ActiveSupport::Concern

  COOKIE = :device_token
  LIFETIME = 2.years

  included do
    before_action :resume_pairing
    helper_method :paired?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :resume_pairing, **options
    end
  end

  private

  def paired?
    Current.child.present?
  end

  def resume_pairing
    Current.device ||= Device.find_by_token(cookies[COOKIE])
    return unless Current.child

    Current.device.touch_last_seen
    write_pairing_cookie cookies[COOKIE]
  end

  def start_pairing_for(pairing_link)
    pairing_link.claim!.tap do |device|
      Current.device = device
      write_pairing_cookie device.plain_token
    end
  end

  # Neither signed nor encrypted: the device row is the identity of record and has to be read
  # anyway, while a signed cookie dies with the secret key base and an iPad has no way back
  # from that on its own. `secure:` is force_ssl's job, so development over plain HTTP pairs.
  def write_pairing_cookie(token)
    cookies[COOKIE] = {value: token, httponly: true, same_site: :lax, expires: LIFETIME.from_now}
  end
end
