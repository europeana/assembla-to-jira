# frozen_string_literal: true

load './lib/common.rb'

# TODO: For the time being this is hard-coded
SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# users_csv = "#{dirname}/report-users.csv"
# users = csv_to_array(users_csv)
#
# @user_id_to_login = {}
# users.each do |user|
#   @user_id_to_login[user['id']] = user['login']
# end

# Assembla comments, tags and attachment csv files: ticket_number and ticket_id

comments_assembla_csv = "#{dirname_assembla}/ticket-comments.csv"

@comments_assembla = csv_to_array(comments_assembla_csv)

# JIRA csv files: jira_ticket_id, jira_ticket_key, assembla_ticket_id, assembla_ticket_number

tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

@tickets = []

# POST /rest/api/2/issue/{issueIdOrKey}/comment
def jira_create_comment(issue, comment)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue[:id]}/comment"
  body = "Author [~#{comment['user_name']}] | Created on #{date_time(comment['created_on'])}\n\n#{reformat_markdown(comment['comment'])}"
  # user_id = comment['user_id']
  # user_login = @user_id_to_login[user_id]
  payload = {
    body: body
  }.to_json
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
    # TODO: Investigate why the following does not work, e.g. reporter can create own comments.
    # response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers_user_login(user_login))
    result = JSON.parse(response.body)
    puts "POST #{url} => OK"
  rescue RestClient::ExceptionWithResponse => e
    error = JSON.parse(e.response)
    message = error['errors'].map { |k, v| "#{k}: #{v}" }.join(' | ')
    puts "POST #{url}  => NOK (#{message})"
  rescue => e
    puts "POST #{url} => NOK (#{e.message})"
  end
  result
end

@tickets_jira.each do |ticket|
  next unless ticket['result'] == 'OK'
  @tickets << {
    jira: {
      id: ticket['jira_ticket_id'],
      key: ticket['jira_ticket_key']
    },
    assembla: {
      id: ticket['assembla_ticket_id'],
      number: ticket['assembla_ticket_number']
    }
  }
end

# Convert assembla_ticket_id to jira_ticket
@assembla_id_to_jira = {}
@tickets.each_with_index do |ticket|
  jira = ticket[:jira]
  assembla = ticket[:assembla]
  @assembla_id_to_jira[assembla[:id]] = jira
end

@ok = []
@nok = []

# Important: Make sure that the comments are ordered chronologically from first (oldest) to last (newest)
@comments_assembla.sort! { |x, y| x['created_on'] <=> y['created_on'] }

@comments_assembla.each_with_index do |comment|
  assembla_ticket_id = comment['ticket_id']
  jira_issue = @assembla_id_to_jira[assembla_ticket_id]
  if jira_issue.nil?
    @nok << assembla_ticket_id unless @nok.include?(assembla_ticket_id)
  else
    # TODO: check for success
    result = jira_create_comment(jira_issue, comment)
    jira_id = result['id']
    @ok << assembla_ticket_id unless @ok.include?(assembla_ticket_id)
  end
end

puts "#{@ok.length} valid tickets"
puts "#{@nok.length} invalid tickets"
