# The agent's whole surface on this app: every read and write of its data is one of these,
# and `Ops.help` is the listing of them.
module Ops
  class << self
    def help
      load_operations
      puts registry.to_text
    end

    def registry
      @_registry ||= Registry.new
    end

    private

    # Autoloading is lazy, so an operation nothing has referenced yet has not declared
    # itself and would be missing from the listing.
    def load_operations
      Rails.autoloaders.main.eager_load_dir Rails.root.join("app/operations")
    end
  end
end
