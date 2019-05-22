class WebhookDeliveryJob < Postal::Job
  def perform
    logger = Postal.logger_for(:delivery)
    logger.info "I'm in WebhookDeliveryJob"
    if webhook_request = WebhookRequest.find_by_id(params['id'])
      logger.info "WebhookDeliveryJob webhook_request: #{webhook_request.to_s}"
      if webhook_request.deliver
        log "Succesfully delivered"
      else
        log "Delivery failed"
      end
    else
      log "No webhook request found with ID '#{params['id']}'"
    end
  end
end
