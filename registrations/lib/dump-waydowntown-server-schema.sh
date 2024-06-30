cd ../waydowntown/waydowntown_server
bundle exec rake db:schema:dump
bundle exec rubocop -A db/schema.rb > /dev/null
echo "waydowntown server schema dumped successfully"
