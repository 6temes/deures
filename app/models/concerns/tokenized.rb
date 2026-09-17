# A token handed out once in plaintext and kept only as a digest: every lookup hashes what the
# caller presents, so the plaintext is never stored and the row itself is what can be revoked.
module Tokenized
  extend ActiveSupport::Concern

  included do
    attr_reader :plain_token

    before_validation :generate_token, on: :create

    validates :token_digest, presence: true, uniqueness: true
  end

  class_methods do
    def find_by_token(token)
      return if token.blank?

      find_by token_digest: Digest::SHA256.hexdigest(token)
    end
  end

  private

  def generate_token
    @plain_token = SecureRandom.urlsafe_base64(32)
    self.token_digest = Digest::SHA256.hexdigest(@plain_token)
  end
end
