# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = 'Europeana Collections'

@jira_users = []

def create_user(user)
  url = "#{JIRA_API_HOST}/user"
  username = user['login']
  email = user['email']
  if email.nil? || email.length == 0
    email = "#{username}@example.org"
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
  next if count == '0'
  u1 = jira_get_user(username)
  if u1
    # User exists so add to list
    @jira_users << u1
  else
    # User does not exist so create if possible and add to list
    u2 = create_user(user)
    @jira_users << u2 if u2
  end
end

write_csv_file(jira_users_csv, @jira_users)