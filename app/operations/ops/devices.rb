module Ops
  module Devices
    class Forget < Ops::Base
      include Lookups

      operation name: "devices.forget",
        description: "Forget a child's devices, so each iPad signs in again from a link issued for it.",
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
          "issue a link for each iPad that is to sign in again"
      end

      private

      def signed_in(child)
        child.devices.where(forgotten_at: nil).to_a
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
        token = link.generate_token_for(:invitation)
        url = "#{@origin}#{Rails.application.routes.url_helpers.pairing_path(token:)}"

        puts QrCode.render(url, caption: child.name, color: child.color_hex)
        "#{child.name}: pairing links #{before} → #{child.pairing_links.count}, " \
          "expires #{PairingLink::WINDOW.from_now.strftime("%H:%M")} and pairs one iPad, #{url}"
      end
    end
  end
end
