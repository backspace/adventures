require 'premailer'

BASE_URL = ARGV[0]

premailer = Premailer.new('/tmp/email.html', :warn_level => Premailer::Warnings::SAFE, :base_url => BASE_URL)

puts premailer.to_inline_css.split("\n").reject{|line| line.include?("background-attachment") && line.include?("svg")}.join("\n")
