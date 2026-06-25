# frozen_string_literal: true

require "net/http"
require "uri"

module Kotoshu
  module Integrity
    # Thin wrapper around Net::HTTP so manifest fetches are testable
    # without the network. Returns response body as a String on 2xx,
    # nil on 404/410 (so callers can treat "manifest not published yet"
    # as graceful degradation), and raises on other errors.
    module NetHTTP
      class << self
        def get(url, redirect_limit: 3)
          uri = URI(url)
          raise ArgumentError, "Only http/https supported: #{url}" unless
            uri.scheme == "http" || uri.scheme == "https"

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == "https")
          http.open_timeout = 10
          http.read_timeout = 30

          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)

          case response
          when Net::HTTPSuccess
            response.body
          when Net::HTTPNotFound, Net::HTTPGone
            nil
          when Net::HTTPRedirection
            raise TooManyRedirects if redirect_limit.zero?

            get(response["location"], redirect_limit: redirect_limit - 1)
          else
            raise HttpError, "GET #{url} failed: #{response.code} #{response.message}"
          end
        end
      end

      class HttpError < StandardError; end
      class TooManyRedirects < StandardError; end
    end
  end
end
