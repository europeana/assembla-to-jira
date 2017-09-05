# frozen_string_literal: true

load './lib/common.rb'

# TODO: For the time being this is hard-coded
SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

comments_assembla_csv = "#{dirname_assembla}/ticket-comments.csv"
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"

@comments_assembla = csv_to_array(comments_assembla_csv)
@tickets_jira = csv_to_array(tickets_jira_csv)

@tickets = []

@tickets_jira.each do |ticket|
  @tickets << {
    jira: {
      id: ticket['jira_ticket_id'],
      key: ticket['jira_ticket_key']
    },
    assembla: {
      id: ticket['assembla_ticket_id'],
      number: ticket['assembla_ticket_number']
    },
    issue_type: {
      id: ticket['issue_type_id'],
      name: ticket['issue_type_name']
    }
  }
end

@tickets.each_with_index do |ticket, index|
  jira = ticket[:jira]
  assembla = ticket[:assembla]
  issue_type = ticket[:issue_type]
  puts "#{index}: #{jira[:id]} (#{jira[:key]}), #{assembla[:id]} (#{assembla[:number]}), #{issue_type[:id]} (#{issue_type[:name]})"
end
