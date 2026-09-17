module Ops
  module Devices
    class Forget < Ops::Base
      include Lookups

      operation name: "devices.forget",
        description: "Forget a child's devices, so the next launch of the installed icon pairs itself again.",
        example: %(Ops::Devices::Forget.call child: "Pau", confirm: true),
        confirm: true

      def initialize(child:)
        @name = child
      end

      def perform
        child = child! @name
        devices = signed_in child
        refuse! "#{child.name} has no device signed in — issue a pairing link and open it on the iPad" if devices.empty?

        devices.each(&:forget!)

        "#{child.name}: devices signed in #{devices.size} → #{signed_in(child).size}, " \
          "#{live_links child} pairing links still live"
      end

      private

      def live_links(child)
        child.pairing_links.where(revoked_at: nil).count
      end

      def signed_in(child)
        Device.where(forgotten_at: nil, pairing_link: child.pairing_links.where(revoked_at: nil)).to_a
      end
    end

    class IssueLink < Ops::Base
      include Lookups

      operation name: "devices.issue_link",
        description: "Issue a pairing link for a child and print it as a code the iPad camera reads.",
        example: %(Ops::Devices::IssueLink.call child: "Pau")

      # Every request reaches this app through a reverse proxy, so it never learns the host it
      # answers on; the console is told, and passes `at:` for a development machine on the LAN.
      def initialize(child:, at: nil)
        @name, @origin = child, at || "https://#{ENV.fetch("APP_HOST", "study.example.com")}"
      end

      def perform
        child = child! @name
        before = child.pairing_links.count
        link = child.pairing_links.create!
        url = "#{@origin}#{Rails.application.routes.url_helpers.pairing_path link.plain_token}"

        puts QrCode.render(url, caption: child.name, color: child.color_hex)
        "#{child.name}: pairing links #{before} → #{child.pairing_links.count}, #{url}"
      end
    end

    class RevokeLink < Ops::Base
      include Lookups

      operation name: "devices.revoke_link",
        description: "Revoke a child's pairing links, signing out every device that used them.",
        example: %(Ops::Devices::RevokeLink.call child: "Pau", confirm: true),
        confirm: true

      def initialize(child:, issued_on: nil)
        @name, @issued_on = child, issued_on
      end

      def perform
        child = child! @name
        links = revocable(child).to_a
        refuse! "#{child.name} has no pairing link left to revoke — issue one first" if links.empty?

        before = live(child)
        signed_out = Device.where(forgotten_at: nil, pairing_link_id: links.map(&:id)).count
        links.each(&:revoke!)

        "#{child.name}: pairing links #{before} → #{live child} live, #{signed_out} devices signed out"
      end

      private

      def live(child)
        child.pairing_links.where(revoked_at: nil).count
      end

      def revocable(child)
        links = child.pairing_links.where revoked_at: nil
        return links unless @issued_on

        links.where created_at: to_date(@issued_on).all_day
      end
    end
  end
end
