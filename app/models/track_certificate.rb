# == Schema Information
#
# Table name: track_certificates
#
#  id                  :integer          not null, primary key
#  domain              :string(255)
#  certificate         :text(65535)
#  intermediaries      :text(65535)
#  key                 :text(65535)
#  expires_at          :datetime
#  renew_after         :datetime
#  verification_path   :string(255)
#  verification_string :string(255)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_track_certificates_on_domain  (domain)
#

class TrackCertificate < ApplicationRecord

  validates :domain, :presence => true, :uniqueness => true

  default_value :key, -> { OpenSSL::PKey::RSA.new(2048).to_s }

  scope :active, -> { where("certificate IS NOT NULL AND expires_at > ?", Time.now) }

  def active?
    certificate.present?
  end

  def get
    issue
  end

  def issue
    order = Postal::LetsEncrypt.client.new_order(identifiers: [self.domain])
    authorization = order.authorizations.first
    challenge = authorization.http01
    self.verification_path = challenge.filename
    self.verification_string = challenge.file_content
    self.save!
    logger.info "Attempting verification of #{self.domain}"
    challenge.request_validation
    checks = 0
    until challenge.status != "pending"
      checks += 1
      if checks > 30
        logger.info "Status remained at pending for 30 checks"
        return false
      end
      sleep 1
    end

    unless challenge.status == "valid"
      logger.info "Status was not valid (was: #{challenge.status})"
      return false
    end

    private_key = OpenSSL::PKey::RSA.new(self.key)
    csr = Acme::Client::CertificateRequest.new(private_key: private_key, subject: {common_name: self.domain})
    logger.info "Getting certificate for #{self.domain}"
    order.finalize(csr: csr)
    sleep(1) while order.status == 'processing'
    https_cert = order.certificate
    logger.info https_cert
    self.certificate = https_cert
    https_cert_x509 = OpenSSL::X509::Certificate.new https_cert
    self.expires_at = https_cert_x509.not_after
    self.renew_after = (self.expires_at - 1.month) + rand(10).days
    self.save!
    logger.info "Certificate issued (expires on #{self.expires_at}, will renew after #{self.renew_after})"
    return true

  rescue Acme::Client::Error => e
    @retries = 0
    if e.is_a?(Acme::Client::Error::BadNonce) && @retries < 5
      @retries += 1
      logger.info "Bad nounce encountered. Retrying (#{@retries} of 5 attempts)"
      logger.info "Error: #{e.class} (#{e.message})"
      sleep 1
      issue
    else
      logger.info "Error: #{e.class} (#{e.message})"
      return false
    end
  end

  def certificate_object
    @certificate_object ||= OpenSSL::X509::Certificate.new(self.certificate)
  end

  def intermediaries_array
    @intermediaries_array ||= self.intermediaries.to_s.scan(/-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----/m).map{|c| OpenSSL::X509::Certificate.new(c)}
  end

  def key_object
    @key_object ||= OpenSSL::PKey::RSA.new(self.key)
  end

  def logger
    Postal::LetsEncrypt.logger
  end

end
