#!/usr/bin/env ruby

require 'openssl'
require 'base64'

cipher = OpenSSL::Cipher.new('aes256')
cipher.encrypt
key = cipher.random_key
iv = cipher.random_iv

puts "Key: #{Base64.urlsafe_encode64(key, padding: false)}"
puts "IV: #{Base64.urlsafe_encode64(iv, padding: false)}"