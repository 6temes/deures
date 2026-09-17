# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self

    # Nothing here is fetched from anywhere but this origin: no webfont, no CDN, no
    # analytics. `data:` is for the SVG favicon's own inline swap.
    policy.img_src :self, :data
    policy.font_src :self
    policy.media_src :self
    policy.connect_src :self
    policy.manifest_src :self

    policy.script_src :self
    policy.style_src :self

    # The `--i` and `--child-light` custom properties are set as `style` attributes, which a
    # nonce cannot cover — `style-src-attr` is the only directive that reaches them. Without
    # this line they fall back to `style-src`, where the nonce blocks every one of them.
    policy.style_src_attr :unsafe_inline

    policy.frame_ancestors :none
  end

  # A fresh nonce per request rather than the session id: the install screen is reached with
  # no session yet, and `session.id.to_s` is "" there — an empty nonce matches nothing, so the
  # one screen a parent ever sees would be the one that breaks.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }

  # `script-src` carries the importmap and its module shim; `style-src` carries the element
  # Turbo injects for the progress bar, which reads the nonce from `csp_meta_tag`.
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
