require_relative "../worktree"

# Browsers keep cookies per host, not per port, so a linked worktree serving beside the main
# checkout on localhost names its session cookie after itself; otherwise signing in to one signs
# the other out. Authentication::COOKIE does the same for the pairing cookie.
worktree = Worktree.identity(Rails.root.to_s) if Rails.env.development?
Rails.application.config.session_store :cookie_store, key: ["_deures_session", worktree].compact.join("_")
