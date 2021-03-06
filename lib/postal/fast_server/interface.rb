module Postal
  module FastServer
    class Interface

      # TODO: Make this multithreaded? Thread-safe?

      TRACKING_PIXEL = File.read(Rails.root.join('app', 'assets', 'images', 'tracking_pixel.png'))

      def get_message_db_from_server_token(token)
        if server = ::Server.find_by_token(token)
          server.message_db
        else
          nil
        end
      end

      def get_server_id
        ::Server.all.first.message_db.server_id
      end

      def call(env)
        request = Rack::Request.new(env)

        if request.path.start_with?('/l/')
          Postal.logger_for(:fast_server).info("links | incoming path: #{request.path}")
          begin
            encoded = request.path.split('/').last
            decoded64 = Base64.urlsafe_decode64(encoded)

            require 'openssl'
            decipher     = OpenSSL::Cipher.new('aes256').decrypt
            decipher.key = Base64.urlsafe_decode64(Postal.config.track_links.cipher_key)
            decipher.iv  = Base64.urlsafe_decode64(Postal.config.track_links.cipher_iv)

            begin
              decoded = decipher.update(decoded64) + decipher.final
            rescue OpenSSL::Cipher::CipherError => e
              Postal.logger_for(:fast_server).error("links | can't decode: #{e.message}")
              return [404, {}, ['Not found']]
            end

            decoded = decoded.split(Postal.config.track_links.separator)

            link = {}
            link['version']    = Base64.urlsafe_decode64(decoded[0])
            link['message_id'] = Base64.urlsafe_decode64(decoded[1])
            link['url']        = Base64.urlsafe_decode64(decoded[2])

            Postal.logger_for(:fast_server).info("links | decoded - version:#{link['version']}, message_id:#{link['message_id']}, url:#{link['url']}")

            SendWebhookJob.queue(
              :webhooks,
              server_id: get_server_id,
              event: 'MessageLinkClicked',
              payload: {
                _message:   link['message_id'],
                url:        link['url'],
                ip_address: request.ip,
                user_agent: request.user_agent
              }
            )

            Postal.logger_for(:fast_server).info("links | webhook queued")

            return [307, {'Location' => link['url']}, ["Redirected to: #{link['url']}"]]
          rescue StandardError => e
            Postal.logger_for(:fast_server).error("links | error in path decode: #{e.message}")
            return [500, {}, ['Sorry, try later']]
          end
        end

        if request.path =~ /\A\/(\.well-known\/.*)/
          if certificate = ::TrackCertificate.find_by_verification_path($1)
            return [200, {'Content-Length' => certificate.verification_string.bytesize.to_s}, [certificate.verification_string]]
          else
            return [404, {}, ["Verification not found"]]
          end

        elsif request.path =~ /\A\/img\/([a-z0-9\-]+)\/([a-z0-9\-]+)/i
          server_token = $1
          message_token = $2

          if message_db = get_message_db_from_server_token(server_token)
            begin
              message = message_db.message(:token => message_token)
              message.create_load(request)
            rescue Postal::MessageDB::Message::NotFound
              # This message has been removed, we'll just continue to serve the image
            rescue => e
              # Somethign else went wrong. We don't want to stop the image loading though because
              # this is our problem. Log this exception though.
              if defined?(Raven)
                Raven.capture_exception(e)
              end
            end
            source_image = request.params['src']
            if source_image.nil?
              headers = {}
              headers['Content-Type'] = "image/png"
              headers['Content-Length'] = TRACKING_PIXEL.bytesize.to_s
              return [200, headers, [TRACKING_PIXEL]]
            elsif source_image =~ /\Ahttps?\:\/\//
              response = Postal::HTTP.get(source_image, :timeout => 3)
              if response[:code] == 200
                headers = {}
                headers['Content-Type'] = response[:headers]['content-type']&.first
                headers['Last-Modified'] = response[:headers]['last-modified']&.first
                headers['Cache-Control'] = response[:headers]['cache-control']&.first
                headers['Etag'] = response[:headers]['etag']&.first
                headers['Content-Length'] = response[:body].bytesize.to_s
                return [200, headers, [response[:body]]]
              else
                return [404, {}, ['Not found']]
              end
            else
              return [400, {}, ['Invalid/missing source image']]
            end
          else
            return [404, {}, ['Invalid Server Token']]
          end
        end

        if request.path =~ /\A\/([a-z0-9\-]+)\/([a-z0-9\-]+)/i
          server_token = $1
          link_token = $2
          if message_db = get_message_db_from_server_token(server_token)
            if link = message_db.select(:links, :where => {:token => link_token}, :limit => 1).first
              time = Time.now.to_f
              if link['message_id']
                message_db.update(:messages, {:clicked => time}, :where => {:id => link['message_id']})
                message_db.insert(:clicks, {:message_id => link['message_id'], :link_id => link['id'], :ip_address => request.ip, :user_agent => request.user_agent, :timestamp => time})
                SendWebhookJob.queue(:webhooks, :server_id => message_db.server_id, :event => 'MessageLinkClicked', :payload => {:_message => link['message_id'], :url => link['url'], :token => link['token'], :ip_address => request.ip, :user_agent => request.user_agent})
              end
              return [307, {'Location' => link['url']}, ["Redirected to: #{link['url']}"]]
            else
              return [404, {}, ['Link not found']]
            end
          else
            return [404, {}, ['Invalid Server Token']]
          end
        end

        [200, {}, ["Hello."]]
      end

    end
  end
end
