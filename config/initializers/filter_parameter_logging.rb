# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]

# `:token` above covers the pairing token as a *parameter*, and a pairing URL carries it as a
# path segment, which `filtered_path` passes through untouched. Scrubbing it out of the logs,
# the traces and the captured errors is pairing_token_redaction.rb.
