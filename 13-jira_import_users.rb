# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']

@jira_users = []

space = get_space(SPACE_NAME)
dirname = get_output_dirname(space, 'assembla')
users_csv = "#{dirname}/report-users.csv"
jira_users_csv = "#{OUTPUT_DIR_JIRA}/jira-users.csv"

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
    u2 = jira_create_user(user)
    @jira_users << u2 if u2
  end
end

write_csv_file(jira_users_csv, @jira_users)

inactive_users = @jira_users.select{ |user| user['active'] == false}

unless inactive_users.length.zero?
  puts "The following users need to be activated: #{inactive_users.map{|user| user['name']}.join(', ')}"
end