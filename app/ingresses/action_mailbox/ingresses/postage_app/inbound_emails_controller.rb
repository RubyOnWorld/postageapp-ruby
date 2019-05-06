# frozen_string_literal: true

class ActionMailbox::Ingresses::PostageApp::InboundEmailsController < ActionMailbox::BaseController
  before_action :hmac_authenticate

  def create
    ActionMailbox::InboundEmail.create_and_extract_message_id!(message_param)

    head(:ok)

  rescue JSON::ParserError => e
    logger.error(e.message)

    head(:unprocessable_entity)
  end

private
  def message_param
    params.require(:inbound_email).require(:message)
  end

  def hmac_authenticate
    return if (hmac_authenticated?)

    head(:unauthorized)
  end

  def hmac_authenticated?
    if (PostageApp.config.postback_secret.present?)
      ActiveSupport::SecurityUtils.secure_compare(
        request.headers["X-PostageApp-Signature"],
        hmac_signature(
          message: message_param,
          secret: PostageApp.config.postback_secret
        )
      )
    else
      raise ArgumentError, <<~END.squish
        Missing required PostageApp postback secret which can be set as
        postageapp: postback_secret: in the Rails Encypted Credentials, as
        POSTAGEAPP_API_POSTBACK_SECRET in the environment, or via a
        config/initializer script using the PostageApp.config method.
      END
    end
  end

private
  def hmac_signature(message:, secret:)
    Base64.strict_encode64(
      OpenSSL::HMAC.digest(OpenSSL::Digest::SHA1.new, secret, message)
    )
  end
end
