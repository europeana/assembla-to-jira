# frozen_string_literal: true

load './lib/common.rb'

# TODO: For the time being this is hard-coded
SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' TEST' : '')

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

# Assembla comments, tags and attachment csv files: ticket_number and ticket_id

tickets_assembla_csv = "#{dirname_assembla}/tickets.csv"

comments_assembla_csv = "#{dirname_assembla}/ticket-comments.csv"
comments_ok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments-ok.csv"
comments_nok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-comments-nok.csv"

tags_assembla_csv = "#{dirname_assembla}/ticket-tags.csv"
tags_ok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tags-ok.csv"
tags_nok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tags-nok.csv"

attachments_assembla_csv = "#{dirname_assembla}/ticket-attachments.csv"
attachments_ok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-ok.csv"
attachments_nok_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-nok.csv"

@tickets_assembla = csv_to_array(tickets_assembla_csv)
@comments_assembla = csv_to_array(comments_assembla_csv)
@tags_assembla = csv_to_array(tags_assembla_csv)
@attachments_assembla = csv_to_array(attachments_assembla_csv)

# JIRA csv files: jira_ticket_id, jira_ticket_key, assembla_ticket_id, assembla_ticket_number, issue_type_id and issue_type_name

tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

@tickets_jira.each_with_index do |ticket_jira, index|
  id = ticket_jira['assembla_ticket_id']
  number = ticket_jira['assembla_ticket_number']
  if @tickets_assembla.find { |ticket_assembla| ticket_assembla['id'] == id}
    unless @tickets_assembla.find { |ticket_assembla| ticket_assembla['number'] == number}
      puts "Line #{index + 1}: Jira tickets: cannot find Assembla ticket with number='#{number}'"
    end
  else
    puts "Line #{index + 1}: Jira tickets: cannot find Assembla ticket with id='#{id}'"
  end
end

@tickets_assembla.each_with_index do |ticket_assembla, index|
  id = ticket_assembla['id']
  number = ticket_assembla['number']
  if @tickets_jira.find { |ticket_jira| ticket_jira['assembla_ticket_id'] == id}
    unless @tickets_jira.find { |ticket_jira| ticket_jira['assembla_ticket_number'] == number}
      puts "Line #{index + 1}: Assembla tickets: cannot find Jira ticket with assembla_ticket_number='#{number}'"
    end
  else
    puts "Line #{index + 1}: Assembla tickets: cannot find Jira ticket with assembla_ticket_id='#{id}'"
  end
end

exit

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

  puts "jira_ticket_id,jira_ticket_key,assembla_ticket_id,assembla_ticket_number" if index.zero?
  puts "#{jira_ticket_id},#{jira_ticket_key},#{assembla_ticket_id},#{assembla_ticket_number}"

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
@tickets.each_with_index do |ticket, index|
  jira = ticket[:jira]
  assembla = ticket[:assembla]
  issue_type = ticket[:issue_type]
  # puts "#{index}: #{jira[:id]} (#{jira[:key]}), #{assembla[:id]} (#{assembla[:number]}), #{issue_type[:id]} (#{issue_type[:name]})"
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

# @comments_assembla.each_with_index do |comment, index|
#   assembla_ticket_number = comment['ticket_number'].to_i
#   jira_issue = @assembla_number_to_jira[assembla_ticket_number]
#   if jira_issue.nil?
#     puts "Comments line #{index + 1}: assembla_ticket_number=#{assembla_ticket_number} NOK"
#     @comments_nok << comment
#   end
# end

puts "Comments #{@comments_ok.length} valid tickets"
puts "Comments #{@comments_nok.length} invalid tickets:\n#{@comments_nok.join("\n")}"

# if @comments_nok.length.positive?
#   write_csv_file(comments_nok_jira_csv, @comments_nok)
# end

exit

@tags_nok = []

@tags_assembla.each_with_index do |comment, index|
  assembla_ticket_id = comment['ticket_id']
  jira_issue = @assembla_id_to_jira[assembla_ticket_id]
  if jira_issue.nil?
    @tags_nok << comment
    puts "Tags line #{index + 1}: assembla_ticket_id=#{assembla_ticket_id} NOK"
  end
end

puts "Valid tags: #{@tags_assembla.length - @tags_nok.length}"
puts "Invalid tags: #{@tags_nok.length}"

if @tags_nok.length.positive?
  write_csv_file(tags_nok_jira_csv, @tags_nok)
end

@attachments_nok = []

@attachments_assembla.each do |comment|
  assembla_ticket = comment['ticket_id']
  unless assembla_ticket.nil? || assembla_ticket.match(/^\d+$/)
    goodbye("Could not find valid assembla_ticket='#{assembla_ticket}' for comment=#{comment.inspect}")
  end
  jira_ticket = @assembla_id_to_jira[assembla_ticket]
  if jira_ticket.nil? || !jira_ticket.match(/^\d+$/)
    @attachments_nok << comment
  else
    # puts "#{assembla_ticket} => #{jira_ticket}"
  end
end

puts "Valid attachments: #{@attachments_assembla.length - @attachments_nok.length}"
puts "Invalid attachments: #{@attachments_nok.length}"

if @attachments_nok.length.positive?
  write_csv_file(attachments_nok_jira_csv, @attachments_nok)
end
