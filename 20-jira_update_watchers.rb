# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']
JIRA_PROJECT_NAME = SPACE_NAME + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# Assembla users
users_csv = "#{dirname_assembla}/report-users.csv"
users = csv_to_array(users_csv)
@user_id_to_login = {}
users.each do |user|
  @user_id_to_login[user['id']] = user['login'].sub(/@.*$/,'')
end

# Assembla tickets
tickets_csv = "#{dirname_assembla}/tickets.csv"
@tickets_assembla = csv_to_array(tickets_csv)

# --- Filter by date if TICKET_CREATED_ON is defined --- #
tickets_created_on = get_tickets_created_on

if tickets_created_on
  puts "\nFilter newer than: #{tickets_created_on}"
  @tickets_assembla.select! { |item| item_newer_than?(item, tickets_created_on) }
end

@total_assembla_tickets = @tickets_assembla.length
puts "\nTotal Assembla tickets: #{@total_assembla_tickets}"

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

# Convert assembla_ticket_id to jira_ticket
@assembla_id_to_jira = {}
@tickets_jira.each do |ticket|
  assembla_id = ticket['assembla_ticket_id']
  jira_id = ticket['jira_ticket_id']
  @assembla_id_to_jira[assembla_id] = jira_id
end

# POST /rest/api/2/issue/{issueIdOrKey}/watchers
def jira_update_watcher(issue_id, watcher, counter)
  result = nil
  url = "#{URL_JIRA_ISSUES}/#{issue_id}/watchers"
  payload = "\"#{watcher}\""
  begin
    percentage = ((counter * 100) / @total_assembla_tickets).round.to_s.rjust(3)
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
    puts "#{percentage}% [#{counter}|#{@total_assembla_tickets}] POST #{url} '#{watcher}' => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "#{percentage}% [#{counter}|#{@total_assembla_tickets}] POST #{url} #{watcher} => NOK (#{e.message})"
  end
  result
end

@jira_updates_tickets = []

@tickets_assembla.each_with_index do |ticket, index|
  assembla_ticket_id = ticket['id']
  assembla_ticket_watchers = ticket['notification_list']
  jira_ticket_id = @assembla_id_to_jira[assembla_ticket_id]
  assembla_ticket_watchers.split(',').each do |user_id|
    watcher = @user_id_to_login[user_id]
    result = jira_update_watcher(jira_ticket_id, watcher, index + 1)
    @jira_updates_tickets << {
      result: result.nil? ? 'NOK' : 'OK',
      assembla_ticket_id: assembla_ticket_id,
      jira_ticket_id: jira_ticket_id,
      assembla_user_id: user_id,
      watcher: watcher
    }
  end
end

puts "\nTotal updates: #{@jira_updates_tickets.length}"
watchers_tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-watchers.csv"
write_csv_file(watchers_tickets_jira_csv, @jira_updates_tickets)
