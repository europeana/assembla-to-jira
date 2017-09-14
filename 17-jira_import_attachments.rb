# frozen_string_literal: true

load './lib/common.rb'

# Jira tickets
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"
@tickets_jira = csv_to_array(tickets_jira_csv)

@assembla_id_to_jira = {}
@tickets_jira.each do |ticket|
  @assembla_id_to_jira[ticket['assembla_ticket_id']] = ticket['jira_ticket_id']
end

# Downloaded attachments
downloaded_attachments_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-download.csv"
@downloaded_attachments = csv_to_array(downloaded_attachments_csv)
@attachments_total = @downloaded_attachments.length

puts "Total attachments: #{@attachments_total}"

attachments_dirname = "#{OUTPUT_DIR_JIRA}/attachments"
FileUtils.mkdir_p(attachments_dirname) unless File.directory?(attachments_dirname)

@jira_attachments = []

@headers = { 'Authorization': "Basic #{Base64.encode64(JIRA_API_ADMIN_USER + ':' + ENV['JIRA_API_ADMIN_PASSWORD'])}", 'X-Atlassian-Token': 'no-check' }

# created_at,assembla_attachment_id,assembla_ticket_id,filename,content_type
@downloaded_attachments.each_with_index do |attachment, index|
  assembla_attachment_id = attachment['assembla_attachment_id']
  assembla_ticket_id = attachment['assembla_ticket_id']
  jira_ticket_id = @assembla_id_to_jira[attachment['assembla_ticket_id']]
  filename = attachment['filename']
  filepath = "#{attachments_dirname}/#{filename}"
  content_type = attachment['content_type']
  created_at = attachment['created_at']
  url = "#{URL_JIRA_ISSUES}/#{jira_ticket_id}/attachments"
  counter = index + 1
  percentage = ((counter * 100) / @attachments_total).round.to_s.rjust(3)
  puts "#{percentage}% [#{counter}|#{@attachments_total}] POST #{url} '#{filename}' (#{content_type}) => OK"
  payload = { mulitpart: true, file: File.new(filepath, 'rb') }
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: @headers)
    result = JSON.parse(response.body)
    jira_attachment_id = result[0]['id']
    @jira_attachments << {
      jira_attachment_id: jira_attachment_id,
      jira_ticket_id: jira_ticket_id,
      assembla_attachment_id: assembla_attachment_id,
      assembla_ticket_id: assembla_ticket_id,
      created_at: created_at,
      filename: filename,
      content_type: content_type
    }
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url)
  end
end

puts "Total all: #{@jira_attachments.length}"
attachments_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-attachments-import.csv"
write_csv_file(attachments_jira_csv, @jira_attachments)
