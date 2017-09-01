# frozen_string_literal: true

require 'json'
require 'csv'
require 'fileutils'
require 'dotenv/load'
require 'rest-client'

@debug = ENV['DEBUG'] == 'true'

ASSEMBLA_SPACES = ENV['ASSEMBLA_SPACES'].split(',').freeze

ASSEMBLA_API_HOST = ENV['ASSEMBLA_API_HOST']
ASSEMBLA_API_KEY = ENV['ASSEMBLA_API_KEY']
ASSEMBLA_API_SECRET = ENV['ASSEMBLA_API_SECRET']
ASSEMBLA_HEADERS = { 'X-Api-Key': ASSEMBLA_API_KEY, 'X-Api-Secret': ASSEMBLA_API_SECRET }.freeze

JIRA_API_HOST = ENV['JIRA_API_HOST']
JIRA_API_USERNAME = ENV['JIRA_API_USERNAME']
JIRA_API_PASSWORD = ENV['JIRA_API_PASSWORD']
JIRA_API_AUTHORIZATION = ENV['JIRA_API_AUTHORIZATION']
JIRA_HEADERS = { 'Authorization': "Basic #{JIRA_API_AUTHORIZATION}", 'Content-Type': 'application/json' }

URL_JIRA_PROJECTS = "#{JIRA_API_HOST}/project"
URL_JIRA_ISSUE_TYPES = "#{JIRA_API_HOST}/issuetype"
URL_JIRA_PRIORITIES = "#{JIRA_API_HOST}/priority"
URL_JIRA_FIELDS = "#{JIRA_API_HOST}/field"
URL_JIRA_ISSUES = "#{JIRA_API_HOST}/issue"

OUTPUT_DIR = 'data'
OUTPUT_DIR_ASSEMBLA = "#{OUTPUT_DIR}/assembla"
OUTPUT_DIR_JIRA = "#{OUTPUT_DIR}/jira"

def build_counter(opts)
  opts[:counter] ? "[#{opts[:counter]}/#{opts[:total]}] " : ''
end

def http_request(url, opts = {})
  response = ''
  counter = build_counter(opts)
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: ASSEMBLA_HEADERS)
    count = get_response_count(response)
    puts "#{counter}GET #{url} => OK (#{count})"
  rescue => e
    if e.class == RestClient::NotFound && e.response.match?(/Tool not found/i)
      puts "#{counter}GET #{url} => OK (0)"
    else
      message = "#{counter}GET #{url} => NOK (#{e.message})"
      if (opts[:continue_onerror])
        puts message
      else
        goodbye(message)
      end
    end
  end
  response
end

def get_response_count(response)
  return 0 if response.nil? || !response.is_a?(String) || response.length.zero?
  begin
    json = JSON.parse(response)
    return 0 unless json.is_a?(Array)
     return json.length
  rescue => e
    return 0
  end
end

def get_space(name)
  response = http_request("#{ASSEMBLA_API_HOST}/spaces")
  json = JSON.parse(response.body)
  space = json.find { |s| s['name'] == name }
  unless space
    goodbye("Couldn't find space with name = '#{name}'")
  end
  space
end

def get_items(items, space)
  items.each do |item|
    url = "#{ASSEMBLA_API_HOST}/spaces/#{space['id']}/#{item[:name]}"
    url += "?#{item[:q]}" if item[:q]
    per_page = item[:q] =~ /per_page/
    page = 1
    in_progress = true
    item[:results] = []
    while in_progress
      full_url = url
      full_url += "&page=#{page}" if per_page
      response = http_request(full_url)
      count = get_response_count(response)
      if count.positive?
        JSON.parse(response).each do |rec|
          item[:results] << rec
        end
        per_page ? page += 1 : in_progress = false
      else
        in_progress = false
      end
    end
  end
  items
end

def create_csv_files(space, items)
  items = [items] unless items.is_a?(Array)
  items.each do |item|
    create_csv_file(space, item)
  end
  puts "#{space['name']} #{items.map{|item| item[:name]}.to_json} => done!"
end

def create_csv_file(space, item)
  dirname = get_output_dirname(space, 'assembla')
  filename = "#{dirname}/#{normalize_name(item[:name])}.csv"
  write_csv_file(filename, item[:results])
end

def export_items(list)
  ASSEMBLA_SPACES.each do |space_name|
    space = get_space(space_name)
    items = get_items(list, space)
    create_csv_files(space, items)
  end
end

def write_csv_file(filename, results)
  puts filename
  CSV.open(filename, 'wb') do |csv|
    results.each_with_index do |result, index|
      csv << result.keys if index.zero?
      row = []
      result.keys.each do |field|
        row.push(result[field])
      end
      csv << row
    end
  end
end

def get_output_dirname(space, dir = nil)
  dirname = "#{OUTPUT_DIR}/#{dir ? (normalize_name(dir) + '/' ) : ''}#{normalize_name(space['name'])}"
  FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
  dirname
end

def normalize_name(s)
  s.downcase.tr(' /_', '-')
end

def csv_to_array(pathname)
  csv = CSV::parse(File.open(pathname, 'r') {|f| f.read })
  fields = csv.shift
  fields = fields.map {|f| f.downcase.tr(' ', '_')}
  csv.collect { |record| Hash[*fields.zip(record).flatten ] }
end

def jira_get_projects
  result = nil
  begin
    response = RestClient::Request.execute(method: :get, url: URL_JIRA_PROJECTS, headers: JIRA_HEADERS)
    result = JSON.parse(response)
    if result
      result.each do |r|
        r.delete_if {|k,v| k.to_s =~ /expand|self|avatarurls/i}
      end
      puts "GET #{URL_JIRA_PROJECTS} => OK (#{result.length})"
    end
  rescue => e
    puts "GET #{URL_JIRA_PROJECTS} => NOK (#{e.message})"
  end
  result
end

def get_project_by_name(name)
  result = nil
  begin
    response = RestClient::Request.execute(method: :get, url: URL_JIRA_PROJECTS, headers: JIRA_HEADERS)
    body = JSON.parse(response.body)
    result = body.find{|h| h['name'] == name}
    if result
      result.delete_if { |k,v| k =~ /expand|self|avatarurls/i}
      puts "GET #{URL_JIRA_PROJECTS} name='#{name}' => OK"
    end
  rescue => e
    puts "GET #{URL_JIRA_PROJECTS} name='#{name}' => NOK (#{e.message})"
  end
  result
end

def jira_get_priorities
  result = []
  begin
    response = RestClient::Request.execute(method: :get, url: URL_JIRA_PRIORITIES, headers: JIRA_HEADERS)
    result = JSON.parse(response.body)
    if result
      result.each do |r|
        r.delete_if { |k,v| k =~ /self|statuscolor|iconurl/i}
      end
      puts "GET #{URL_JIRA_PRIORITIES} => (#{result.length})"
    end
  rescue => e
    puts "GET #{URL_JIRA_PRIORITIES} => NOK (#{e.message})"
  end
  result
end

def jira_get_issue_types
  result = nil
  begin
    response = RestClient::Request.execute(method: :get, url: URL_JIRA_ISSUE_TYPES, headers: JIRA_HEADERS)
    result = JSON.parse(response)
    if result
      result.each do |r|
        r.delete_if {|k,v| k.to_s =~ /self|iconurl|avatarid/i}
      end
      puts "GET #{URL_JIRA_ISSUE_TYPES} => OK (#{result.length})"
    end
  rescue => e
    puts "GET #{URL_JIRA_ISSUE_TYPES} => NOK (#{e.message})"
  end
  result
end

def jira_get_fields
  result = []
  begin
    response = RestClient::Request.execute(method: :get, url: URL_JIRA_FIELDS, headers: JIRA_HEADERS)
    result = JSON.parse(response.body)
    puts "GET #{URL_JIRA_FIELDS} => (#{result.length})"
  rescue => e
    puts "GET #{URL_JIRA_FIELDS} => NOK (#{e.message})"
  end
  result
end

def jira_get_user(username)
  result = nil
  url = "#{JIRA_API_HOST}/user?username=#{username}"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS)
    body = JSON.parse(response.body)
    body.delete_if { |k,v| k =~ /self|avatarurls|timezone|locale|groups|applicationroles|expand/i}
    puts "GET #{url} => OK (#{body.to_json})"
    result = body
  rescue => e
    if e.class == RestClient::NotFound && JSON.parse(e.response)['errorMessages'][0] =~ /does not exist/
      puts "GET #{url} => NOK (does not exist)"
    else
      goodbye("GET #{url} => NOK (#{e.message})")
    end
  end
  result
end

def goodbye(message)
  puts "\nGOODBYE: #{message}"
  exit
end

