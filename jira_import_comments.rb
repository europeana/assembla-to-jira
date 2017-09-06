# frozen_string_literal: true

load './lib/common.rb'

# TODO: For the time being this is hard-coded
SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# Assembla comments, tags and attachment csv files: ticket_number and ticket_id

comments_assembla_csv = "#{dirname_assembla}/ticket-comments.csv"

@comments_assembla = csv_to_array(comments_assembla_csv)

# JIRA csv files: jira_ticket_id, jira_ticket_key, assembla_ticket_id, assembla_ticket_number

tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

@tickets = []

@tickets_jira.each do |ticket|
  next unless ticket['result'] == 'OK'

  @tickets << {
    jira: {
      id: ticket['jira_ticket_id'].to_i,
      key: ticket['jira_ticket_key']
    },
    assembla: {
      id: ticket['assembla_ticket_id'].to_i,
      number: ticket['assembla_ticket_number'].to_i
    }
  }
end

# Convert assembla_ticket_id to jira_issue
@assembla_id_to_jira = {}
@tickets.each_with_index do |ticket, index|
  jira = ticket[:jira]
  assembla = ticket[:assembla]
  # puts "#{index}: #{jira[:id]} (#{jira[:key]}), #{assembla[:id]} (#{assembla[:number]})"
  @assembla_id_to_jira[assembla[:id]] = jira
end

@ok = []
@nok = []

@comments_assembla.each_with_index do |comment, index|
  assembla_ticket_id = comment['ticket_id'].to_i
  jira_issue = @assembla_id_to_jira[assembla_ticket_id]
  if jira_issue.nil?
    # puts "#{index + 1}: #{assembla_ticket_id} NOK"
    @nok << assembla_ticket_id unless @nok.include?(assembla_ticket_id)
  else
    @ok << assembla_ticket_id unless @ok.include?(assembla_ticket_id)
  end
end

puts "#{@ok.length} valid tickets"
puts "#{@nok.length} invalid tickets"
