# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = 'Europeana Collections'

@jira_users = []

def get_user(username)
  result = false
  url = "#{JIRA_API_HOST}/user?username=#{username}"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS)
    body = JSON.parse(response.body)
    body.delete_if { |k,v| k =~ /self|avatarurls|timezone|locale|groups|applicationroles|expand/i}
    puts "GET #{url} => #{body.to_json}"
    @jira_users << body
    result = true
  rescue => e
    if e.class == RestClient::NotFound && JSON.parse(e.response)['errorMessages'][0] =~ /does not exist/
      puts "GET #{url} => does not exist"
    else
      puts "GET #{url} => NOK (#{e.message})"
      exit
    end
  end
  result
end

def create_user(user)
  url = "#{JIRA_API_HOST}/user"
  username = user['login']
  email = user['email']
  if email.nil? || email.length == 0
    email = username
    email.sub!(/@.*$/,'')
  end
  payload = {
    name: username,
    password: username,
    emailAddress: user['email'] || "#{username}@europeana.eu",
    displayName: user['name'],
  }.to_json
  begin
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
    puts "POST #{url} username='#{username}' => OK"
  rescue => e
    puts "POST #{url} username='#{username}' => NOK (#{e.message})"
  end
end

space = get_space(SPACE_NAME)
dirname = get_output_dirname(space, 'assembla')
users_csv = "#{dirname}/report-user-activity.csv"
jira_users_csv = "#{dirname}/jira-users.csv"

users = csv_to_array(users_csv)

users.each do |user|
  count = user['count']
  username = user['login']
  username.sub!(/@.*$/,'')
  next if count == '0' || get_user(username)
  create_user(user)
end

write_csv_file(jira_users_csv, @jira_users)