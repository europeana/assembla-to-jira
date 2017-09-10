# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']
JIRA_PROJECT_NAME = SPACE_NAME + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# Assembla comments, tags and attachment csv files: ticket_number and ticket_id

tickets_assembla_csv = "#{dirname_assembla}/tickets.csv"

comments_assembla_csv = "#{dirname_assembla}/ticket-comments.csv"
# tags_assembla_csv = "#{dirname_assembla}/ticket-tags.csv"
# attachments_assembla_csv = "#{dirname_assembla}/ticket-attachments.csv"

@tickets_assembla = csv_to_array(tickets_assembla_csv)
@comments_assembla = csv_to_array(comments_assembla_csv)
# @tags_assembla = csv_to_array(tags_assembla_csv)
# @attachments_assembla = csv_to_array(attachments_assembla_csv)

# Assembla tickets

@ticket_id_seen = {}
@ticket_nr_seen = {}

@ticket_id_dups = []
@ticket_nr_dups = []

# Sanity check just in case
@tickets_assembla.each_with_index do |ticket, index|
  id = ticket['id']
  nr = ticket['number']
  if id.nil? || nr.nil? || !(id.match(/^\d+$/) && nr.match(/^\d+$/))
    goodbye("Invalid line #{index + 1}: ticket=#{ticket.inspect}")
  end
  if @ticket_id_seen[id]
    @ticket_id_dups << id if @ticket_id_seen[id] == 1
    @ticket_id_seen[id] += 1
  else
    @ticket_id_seen[id] = 1
  end
  if @ticket_nr_seen[nr]
    @ticket_nr_dups << nr if @ticket_nr_seen[nr] == 1
    @ticket_nr_seen[nr] += 1
  else
    @ticket_nr_seen[nr] = 1
  end
end

goodbye("Duplicate ticket ids: #{@ticket_id_dups.join(',')}") if @ticket_id_dups.length.positive?
goodbye("Duplicate ticket nrs: #{@ticket_nr_dups.join(',')}") if @ticket_nr_dups.length.positive?

puts 'Assembla tickets unique => OK'

# JIRA csv files: jira_ticket_id, jira_ticket_key, assembla_ticket_id, assembla_ticket_number, issue_type_id and issue_type_name

tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

@tickets_jira.each_with_index do |ticket_jira, index|
  id = ticket_jira['assembla_ticket_id']
  number = ticket_jira['assembla_ticket_number']
  if @tickets_assembla.detect { |ticket_assembla| ticket_assembla['id'] == id }
    unless @tickets_assembla.detect { |ticket_assembla| ticket_assembla['number'] == number }
      goodbye("#{tickets_jira_csv}:#{index + 1} cannot find Assembla ticket with number='#{number}', ticket_jira='#{ticket_to_s(ticket_jira)}'")
    end
  else
    goodbye("#{tickets_jira_csv}:#{index + 1} cannot find Assembla ticket with id='#{id}', ticket_jira='#{ticket_to_s(ticket_jira)}'")
  end
end

puts 'Jira tickets match Assembla tickets => OK'

@tickets_assembla.each_with_index do |ticket_assembla, index|
  id = ticket_assembla['id']
  number = ticket_assembla['number']
  if @tickets_jira.detect { |ticket_jira| ticket_jira['assembla_ticket_id'] == id }
    unless @tickets_jira.detect { |ticket_jira| ticket_jira['assembla_ticket_number'] == number }
      puts("#{tickets_assembla_csv}:#{index + 1} cannot find Jira ticket with assembla_ticket_number='#{number}'
, ticket_assembla='#{ticket_to_s(ticket_assembla)}'")
    end
  else
    puts("#{tickets_assembla_csv}:#{index + 1} cannot find Jira ticket with assembla_ticket_id='#{id}'," +
         "ticket_assembla='#{ticket_to_s(ticket_assembla)}'")
  end
end

puts 'Assembla tickets match Jira tickets => OK'

@tickets = []

jira_ticket_id_seen = {}
jira_ticket_key_seen = {}
assembla_ticket_id_seen = {}
assembla_ticket_number_seen = {}

@tickets_jira.each_with_index do |ticket, index|
  next unless ticket['result'] == 'OK'
  jira_ticket_id = ticket['jira_ticket_id']
  jira_ticket_key = ticket['jira_ticket_key']
  assembla_ticket_id = ticket['assembla_ticket_id']
  assembla_ticket_number = ticket['assembla_ticket_number']

  puts("Line #{index + 1}: Invalid jira_ticket_id='#{jira_ticket_id}'") unless jira_ticket_id.match(/^\d+$/)
  puts("Line #{index + 1}: Invalid jira_ticket_key='#{jira_ticket_key}'") unless jira_ticket_key.match(/^[A-Z]+\-\d+$/)
  puts("Line #{index + 1}: Invalid assembla_ticket_id='#{assembla_ticket_id}'") unless assembla_ticket_id.match(/^\d+$/)
  puts("Line #{index + 1}: Invalid assembla_ticket_number='#{assembla_ticket_number}'") unless assembla_ticket_number.match(/^\d+$/)

  puts("Line #{index + 1}: already seen jira_ticket_id='#{jira_ticket_id}'") if jira_ticket_id_seen[jira_ticket_id]
  puts("Line #{index + 1}: already seen jira_ticket_key='#{jira_ticket_key}'") if jira_ticket_key_seen[jira_ticket_key]
  puts("Line #{index + 1}: already seen assembla_ticket_id='#{assembla_ticket_id}'") if assembla_ticket_id_seen[assembla_ticket_id]
  puts("Line #{index + 1}: already seen assembla_ticket_number='#{assembla_ticket_number}'") if assembla_ticket_number_seen[assembla_ticket_number]

  jira_ticket_id_seen[jira_ticket_id] = true
  jira_ticket_key_seen[jira_ticket_key] = true
  assembla_ticket_id_seen[assembla_ticket_id] = true
  assembla_ticket_number_seen[assembla_ticket_number] = true

  # puts "jira_ticket_id,jira_ticket_key,assembla_ticket_id,assembla_ticket_number" if index.zero?
  # puts "#{jira_ticket_id},#{jira_ticket_key},#{assembla_ticket_id},#{assembla_ticket_number}"

  @tickets << {
    jira: {
      id: jira_ticket_id.to_i,
      key: jira_ticket_key
    },
    assembla: {
      id: assembla_ticket_id.to_i,
      number: assembla_ticket_number.to_i
    },
    issue_type: {
      id: ticket['issue_type_id'].to_i,
      name: ticket['issue_type_name']
    }
  }
end

# Convert assembla_ticket_id to jira_issue
@assembla_id_to_jira = {}
@assembla_number_to_jira = {}
@tickets.each_with_index do |ticket|
  jira = ticket[:jira]
  assembla = ticket[:assembla]
  @assembla_id_to_jira[assembla[:id]] = jira
  @assembla_number_to_jira[assembla[:number]] = jira
end

@comments_ok = []
@comments_nok = []

@comments_assembla.each_with_index do |comment, index|
  assembla_ticket_id = comment['ticket_id'].to_i
  jira_issue = @assembla_id_to_jira[assembla_ticket_id]
  if jira_issue.nil?
    puts "Comments line #{index + 1}: assembla_ticket_id=#{assembla_ticket_id} NOK"
    @comments_nok << assembla_ticket_id unless @comments_nok.include?(assembla_ticket_id)
  else
    @comments_ok << assembla_ticket_id unless @comments_ok.include?(assembla_ticket_id)
  end
end

puts "Comments #{@comments_ok.length} valid tickets"
puts "Comments #{@comments_nok.length} invalid tickets\n#{@comments_nok.join("\n")}"
